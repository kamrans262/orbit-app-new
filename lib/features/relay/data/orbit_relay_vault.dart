import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../auth/data/orbit_identity_client.dart';
import 'orbit_relay_protocol.dart';

/// Owner/device-bound encrypted SQLite. Only ciphertext, HMAC indexes and
/// encrypted reconciliation/receipt metadata persist. Never store leases
/// for reuse after process restart, plaintext or discoverable peer names.
class OrbitRelayVault {
  OrbitRelayVault({OrbitIdentityClient? identity,FlutterSecureStorage? storage}):
    _identity=identity??OrbitIdentityClient.instance,_storage=storage??const FlutterSecureStorage();
  final OrbitIdentityClient _identity;
  final FlutterSecureStorage _storage;
  final AesGcm _aead=AesGcm.with256bits();
  static const _prefix='orbit.m22.relay.v1.';
  static const maxBytes=5*1024*1024;
  static final Map<String,Future<void>> _locks={};
  Future<T> _serial<T>(String owner,Future<T> Function() action) async {
    final previous=_locks[owner]??Future.value(),done=Completer<void>();
    _locks[owner]=done.future;
    try{await previous;return await action();}
    finally{done.complete();if(identical(_locks[owner],done.future))_locks.remove(owner);}
  }
  Future<void> _check(String owner) async {
    relayCheck(await _identity.currentLocalSocialOwner()==owner,'Relay account changed.');
  }
  Future<String> _path(String owner) async {
    final root=await getApplicationSupportDirectory();
    return root.path+Platform.pathSeparator+'orbit_m22_'+hashes.sha256.convert(utf8.encode(owner)).toString()+'.db';
  }
  Future<T> _db<T>(String owner,Future<T> Function(Database) action)=>_serial(owner,() async {
    await _check(owner);
    final db=await openDatabase(await _path(owner),version:1,singleInstance:false,
      onConfigure:(db)=>db.execute('PRAGMA synchronous = FULL'),
      onCreate:(db,_)=>db.execute('CREATE TABLE relay (idx TEXT PRIMARY KEY, blob TEXT NOT NULL, size INTEGER NOT NULL, expiry INTEGER NOT NULL)'));
    try{await _check(owner);return await action(db);}finally{await db.close();}
  });
  Future<List<int>> _key(String owner,{bool create=false}) async {
    var value=await _storage.read(key:_prefix+owner);
    if(value==null&&create){
      await _check(owner);
      value=base64Encode(await (await _aead.newSecretKey()).extractBytes());
      await _storage.write(key:_prefix+owner,value:value);
    }
    if(value==null)throw const FormatException('Relay local key unavailable.');
    return relayBytes(value,32);
  }
  String _idx(List<int> key,String device,String id)=>hashes.Hmac(hashes.sha256,key)
      .convert(utf8.encode(device+'|'+id)).toString();
  Future<void> put(String owner,String device,String id,Map<String,Object?> item,
      {required int expiry}) async {
    await _db(owner,(db)=>db.transaction((txn) async {
      final key=await _key(owner,create:true),index=_idx(key,device,id);
      await txn.delete('relay',where:'expiry <= ?',whereArgs:[DateTime.now().toUtc().millisecondsSinceEpoch~/1000]);
      final value=jsonEncode({'device':device,'id':id,'item':item});
      final box=await _aead.encrypt(utf8.encode(value),secretKey:SecretKey(key),
        aad:utf8.encode(owner+'|'+index));
      final blob=jsonEncode({'n':base64Encode(box.nonce),'c':base64Encode(box.cipherText),'m':base64Encode(box.mac.bytes)});
      final size=utf8.encode(blob).length;
      final used=Sqflite.firstIntValue(await txn.rawQuery('SELECT COALESCE(SUM(size),0) FROM relay WHERE idx != ?',[index]))??0;
      relayCheck(size+used<=maxBytes,'Relay local queue is full.');
      await _check(owner);
      await txn.insert('relay',{'idx':index,'blob':blob,'size':size,'expiry':expiry},conflictAlgorithm:ConflictAlgorithm.replace);
    }));
  }
  Future<List<Map<String,dynamic>>> pending(String owner,String device,{required int now,int limit=20}) async {
    return _db(owner,(db) async {
      await db.delete('relay',where:'expiry <= ?',whereArgs:[now]);
      final rows=await db.query('relay',limit:100);
      if(rows.isEmpty)return <Map<String,dynamic>>[];
      final key=await _key(owner);
      final out=<Map<String,dynamic>>[];
      for(final row in rows){
        final raw=relayMap(jsonDecode(row['blob'] as String));
        final box=SecretBox(base64Decode(raw['c'] as String),nonce:base64Decode(raw['n'] as String),mac:Mac(base64Decode(raw['m'] as String)));
        final value=relayMap(jsonDecode(utf8.decode(await _aead.decrypt(box,
          secretKey:SecretKey(key),aad:utf8.encode(owner+'|'+(row['idx'] as String))))));
        if(value['device']!=device)continue;
        relayCheck(_idx(key,device,value['id'] as String)==row['idx'],'Relay local index mismatch.');
        out.add(value);
        if(out.length>=limit)break;
      }
      return out;
    });
  }
  Future<Map<String,dynamic>?> get(String owner,String device,String id,{required int now}) async {
    await _check(owner);
    if(!await File(await _path(owner)).exists())return null;
    return _db(owner,(db) async {
      final rows=await db.query('relay',columns:['idx'],limit:1);
      if(rows.isEmpty)return null;
      final key=await _key(owner),index=_idx(key,device,id);
      final found=await db.query('relay',where:'idx = ?',whereArgs:[index],limit:1);
      if(found.isEmpty)return null;
      final row=found.single;
      if((row['expiry'] as int)<=now){await db.delete('relay',where:'idx = ?',whereArgs:[index]);return null;}
      final raw=relayMap(jsonDecode(row['blob'] as String));
      final box=SecretBox(base64Decode(raw['c'] as String),nonce:base64Decode(raw['n'] as String),mac:Mac(base64Decode(raw['m'] as String)));
      final value=relayMap(jsonDecode(utf8.decode(await _aead.decrypt(box,
        secretKey:SecretKey(key),aad:utf8.encode(owner+'|'+index)))));
      relayCheck(value['device']==device&&value['id']==id,'Relay local index mismatch.');
      await _check(owner);
      return relayMap(value['item']);
    });
  }
  Future<void> remove(String owner,String device,String id) async {
    await _db(owner,(db) async {
      final key=await _key(owner);
      await db.delete('relay',where:'idx = ?',whereArgs:[_idx(key,device,id)]);
    });
  }
  Future<void> purge(String owner)=>_serial(owner,() async {
    await _storage.delete(key:_prefix+owner);
    await deleteDatabase(await _path(owner));
  });
}
