import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_messaging_models.dart';

/// A queued send is already encrypted separately for every eligible device.
/// Never persist unsent plaintext or pre-ratchet key state in the outbox.
class OrbitQueuedCiphertext {
  const OrbitQueuedCiphertext({required this.clientId,
    required this.conversationId,required this.kind,
    required this.protocol,required this.groupEpoch,
    required this.envelopes});
  final String clientId,conversationId,kind,protocol;
  final int groupEpoch;
  final List<OrbitCipherEnvelope> envelopes;
  Map<String,Object?> toJson()=>{
    'client_id':clientId,'conversation_id':conversationId,
    'kind':kind,'protocol':protocol,'group_epoch':groupEpoch,
    'envelopes':envelopes.map((e)=>e.toJson()).toList(),
  };
  factory OrbitQueuedCiphertext.fromJson(Map<String,dynamic> j) {
    final raw=j['envelopes'];
    if(raw is! List)throw const FormatException('Malformed encrypted outbox.');
    return OrbitQueuedCiphertext(
      clientId:j['client_id'] as String,
      conversationId:j['conversation_id'] as String,
      kind:j['kind'] as String,protocol:j['protocol'] as String,
      groupEpoch:(j['group_epoch'] as num).toInt(),
      envelopes:raw.map((v){
        final e=Map<String,dynamic>.from(v as Map);
        return OrbitCipherEnvelope(
          deviceId:e['device_id'] as String,
          ciphertextB64:e['ciphertext_b64'] as String,
          headerB64:e['protocol_header_b64'] as String);
      }).toList(growable:false));
  }
}
class OrbitLocalDecryptedMessage {
  const OrbitLocalDecryptedMessage({
    required this.id,required this.conversationId,
    required this.senderId,required this.kind,
    required this.text,required this.createdAt});
  final String id,conversationId,senderId,kind,text;
  final DateTime createdAt;
}

/// Each record is AES-256-GCM encrypted with a random nonce + owner/record
/// associated data. The key stays in OS secure storage, not SQLite.
/// SQLite is durable transport/history storage, NOT a ratchet state store.
/// Ratchet persistence must be implemented by the vetted E2EE binding.
class OrbitMessagingLocalVault {
  OrbitMessagingLocalVault({OrbitIdentityClient? identity,
    FlutterSecureStorage? storage}):
      _identity=identity??OrbitIdentityClient.instance,
      _storage=storage??const FlutterSecureStorage();

  final OrbitIdentityClient _identity;
  final FlutterSecureStorage _storage;
  static const keyPrefix='orbit.m13.localkey.v1.';
  final AesGcm _cipher=AesGcm.with256bits();

  String _name(String owner) {
    final digest=crypto.sha256.convert(utf8.encode(owner)).toString();
    return 'orbit_m13_'+digest+'.db';
  }

  Future<String> _path(String owner) async {
    final folder=await getApplicationSupportDirectory();
    return folder.path+Platform.pathSeparator+_name(owner);
  }
  Future<String> _owner() async {
    final id=await _identity.currentLocalSocialOwner();
    if(id==null||id.isEmpty)throw OrbitIdentityException(
        'Sign in to access locally encrypted Messages.',401);
    return id;
  }
  Future<void> _sameOwner(String owner) async {
    if(await _owner()!=owner)throw OrbitIdentityException(
      'Account changed. Local messaging access denied.',401);
  }

  Future<SecretKey> _key(String owner,{bool create=false}) async {
    final id=keyPrefix+owner;
    var encoded=await _storage.read(key:id);
    if(encoded==null && create){
      await _sameOwner(owner);
      final secret=await _cipher.newSecretKey();
      final bytes=await secret.extractBytes();
      encoded=base64Encode(bytes);
      await _storage.write(key:id,value:encoded);
    }
    if(encoded==null)throw OrbitIdentityException(
        'Local encrypted Messages are unavailable on this device.',403);
    final raw=base64Decode(encoded);
    if(raw.length!=32)throw const FormatException('Invalid local vault key.');
    return SecretKey(raw);
  }

  /// Prevent conversation IDs, message IDs and client retry IDs from
  /// remaining readable in SQLite indexes or journal pages.
  Future<String> _index(String owner,String id) async {
    final raw=await (await _key(owner,create:true)).extractBytes();
    return crypto.Hmac(crypto.sha256,raw)
      .convert(utf8.encode(owner+'|'+id)).toString();
  }

  Future<String> _seal(String owner,String id,String source) async {
    final secret=await _key(owner,create:true);
    final nonce=_cipher.newNonce();
    final box=await _cipher.encrypt(utf8.encode(source),
      secretKey:secret,nonce:nonce,aad:utf8.encode(owner+'|'+id));
    return jsonEncode({
      'n':base64Encode(box.nonce),
      'c':base64Encode(box.cipherText),
      'm':base64Encode(box.mac.bytes),
    });
  }
  Future<String> _unseal(String owner,String id,String encoded) async {
    final key=await _key(owner);
    final obj=Map<String,dynamic>.from(jsonDecode(encoded) as Map);
    final box=SecretBox(base64Decode(obj['c'] as String),
      nonce:base64Decode(obj['n'] as String),
      mac:Mac(base64Decode(obj['m'] as String)));
    final bytes=await _cipher.decrypt(box,secretKey:key,
      aad:utf8.encode(owner+'|'+id));
    return utf8.decode(bytes);
  }

  Future<T> _db<T>(String owner,Future<T> Function(Database db) job) async {
    await _sameOwner(owner);
    final path=await _path(owner);
    final db=await openDatabase(path,version:1,
      onConfigure:(db) async {
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate:(db,version) async {
        await db.execute('CREATE TABLE outbox('
          'client_id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL,'
          'blob_enc TEXT NOT NULL,created_at INTEGER NOT NULL)');
        await db.execute('CREATE INDEX outbox_created ON outbox(created_at)');
        await db.execute('CREATE TABLE history('
          'message_id TEXT PRIMARY KEY,conversation_id TEXT NOT NULL,'
          'sender_id TEXT NOT NULL,kind TEXT NOT NULL,'
          'blob_enc TEXT NOT NULL,created_at INTEGER NOT NULL)');
        await db.execute('CREATE INDEX history_by_conversation '
          'ON history(conversation_id,created_at DESC)');
      },
    );
    try {
      await _sameOwner(owner);
      return await job(db);
    }finally{
      await db.close();
    }
  }

  Future<void> queue(OrbitQueuedCiphertext queued) async {
    final owner=await _owner();
    final clientIndex=await _index(owner,queued.clientId);
    final conversationIndex=await _index(owner,queued.conversationId);
    final encrypted=await _seal(owner,clientIndex,
      jsonEncode(queued.toJson()));
    await _db(owner,(db)=>db.transaction((txn) async{
      await _sameOwner(owner);
      await txn.insert('outbox',{
        'client_id':clientIndex,
        'conversation_id':conversationIndex,
        'blob_enc':encrypted,
        'created_at':0,
      },conflictAlgorithm:ConflictAlgorithm.ignore);
    }));
  }

  Future<List<OrbitQueuedCiphertext>> pending({int limit=40}) async {
    final owner=await _owner();
    return _db(owner,(db) async {
      final rows=await db.query('outbox',
        orderBy:'rowid ASC',limit:limit.clamp(1,40));
      final result=<OrbitQueuedCiphertext>[];
      for(final r in rows){
        final id=r['client_id'] as String;
        final clear=await _unseal(owner,id,r['blob_enc'] as String);
        result.add(OrbitQueuedCiphertext.fromJson(
          Map<String,dynamic>.from(jsonDecode(clear) as Map)));
      }
      await _sameOwner(owner);
      return result;
    });
  }

  Future<void> acknowledge(String clientId) async {
    final owner=await _owner();
    final index=await _index(owner,clientId);
    await _db(owner,(db)=>db.delete('outbox',
      where:'client_id = ?',whereArgs:[index]).then((_){}));
  }

  /// Skip already-committed messages before invoking an irreversible
  /// ratchet decrypt. Server HTTPS polling may replay the same envelope.
  Future<bool> hasMessage(String conversation,String messageId) async {
    final owner=await _owner();
    final messageIndex=await _index(owner,messageId);
    final conversationIndex=await _index(owner,conversation);
    return _db(owner,(db) async {
      final rows=await db.query('history',columns:['message_id'],
        where:'message_id = ? AND conversation_id = ?',
        whereArgs:[messageIndex,conversationIndex],limit:1);
      await _sameOwner(owner);
      return rows.isNotEmpty;
    });
  }

  Future<void> saveDecrypted(OrbitLocalDecryptedMessage message) async {
    final owner=await _owner();
    final index=await _index(owner,message.id);
    final conversationIndex=await _index(owner,message.conversationId);
    // Every private field is sealed, including sender ID, message kind,
    // exact creation time, text and raw conversation/message identifiers.
    final encrypted=await _seal(owner,index,jsonEncode({
      'message_id':message.id,
      'conversation_id':message.conversationId,
      'sender_id':message.senderId,'kind':message.kind,
      'text':message.text,
      'created_at':message.createdAt.toUtc().toIso8601String(),
    }));
    await _db(owner,(db)=>db.insert('history',{
      'message_id':index,'conversation_id':conversationIndex,
      'sender_id':'sealed','kind':'sealed',
      'blob_enc':encrypted,'created_at':0,
    },conflictAlgorithm:ConflictAlgorithm.ignore).then((_){}));
  }

  Future<List<OrbitLocalDecryptedMessage>> history(String conversation,
      {int limit=50}) async {
    final owner=await _owner();
    final index=await _index(owner,conversation);
    return _db(owner,(db) async{
      final rows=await db.query('history',
        where:'conversation_id = ?',whereArgs:[index],
        orderBy:'rowid DESC',limit:limit.clamp(1,100));
      final messages=<OrbitLocalDecryptedMessage>[];
      for(final row in rows) {
        final hashedId=row['message_id'] as String;
        final clear=await _unseal(owner,hashedId,row['blob_enc'] as String);
        final value=Map<String,dynamic>.from(jsonDecode(clear) as Map);
        if(value['conversation_id']!=conversation){
          throw const FormatException('Local encrypted chat index mismatch.');
        }
        messages.add(OrbitLocalDecryptedMessage(
          id:value['message_id'] as String,conversationId:conversation,
          senderId:value['sender_id'] as String,
          kind:value['kind'] as String,text:value['text'] as String,
          createdAt:DateTime.parse(value['created_at'] as String)));
      }
      await _sameOwner(owner);
      messages.sort((a,b)=>a.createdAt.compareTo(b.createdAt));
      return messages;
    });
  }

  /// Wipes the owner's encryption key AND disk DB on logout/account change.
  Future<void> purge(String owner) async {
    if(owner.isEmpty)return;
    await _storage.delete(key:keyPrefix+owner);
    final path=await _path(owner);
    await deleteDatabase(path);
  }
}
