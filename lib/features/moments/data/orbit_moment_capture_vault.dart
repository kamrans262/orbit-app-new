import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../media/data/orbit_media_outbox.dart';

class OrbitRecoveredMomentCapture {
  const OrbitRecoveredMomentCapture({
    required this.kind,
    required this.clientId,
    this.photo,
    this.clip,
    this.durationMs,
    this.edits=const {},
  });
  final String kind;
  final String clientId;
  final Uint8List? photo;
  final File? clip;
  final int? durationMs;
  final Map<String,dynamic> edits;
}

/// Account-scoped encrypted recovery for captures that have not yet entered
/// the M6 media outbox. Source photos are encrypted before being written to
/// disk. Clips are encrypted in bounded chunks; only ciphertext survives a
/// camera route close/restart. Decryption is limited to an active camera route.
///
/// This is NOT a background publisher; the user must review and publish.
class OrbitMomentCaptureVault {
  OrbitMomentCaptureVault({
    OrbitMediaVault? vault,
    Future<String?> Function()? owner,
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? temporaryDirectory,
    OrbitMediaCrypto? crypto,
  }) : _vault=vault??OrbitPlatformMediaVault(),
       _owner=owner??OrbitIdentityClient.instance.currentLocalSocialOwner,
       _support=supportDirectory??getApplicationSupportDirectory,
       _temporary=temporaryDirectory??getTemporaryDirectory,
       _crypto=crypto??OrbitMediaCrypto();

  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;
  final Future<Directory> Function() _support, _temporary;
  final OrbitMediaCrypto _crypto;
  static const maxAge=Duration(days:7);
  static Future<void> _tail=Future<void>.value();
  static Future<T> _serialize<T>(Future<T> Function() action){
    final task=_tail.then((_)=>action());
    _tail=task.then<void>((_){},onError:(Object _,StackTrace __){});
    return task;
  }
  static const maxRecipeBytes=8*1024*1024;
  // Large recipes are encrypted on disk. Only a short authenticated index
  // and key are kept in OS secure storage, never raw drawing/text recipes.
  Future<Map<String,dynamic>> _readEdits(String owner,Map<String,dynamic> data) async {
    final descriptor=data['edit_blob'];
    if(descriptor==null){
      return data['edits'] is Map?Map<String,dynamic>.from(data['edits'] as Map):{};
    }
    if(descriptor is! Map)throw const FormatException('Invalid edit index.');
    final name=descriptor['name'];
    if(name is! String||!RegExp(r'^[a-fA-F0-9-]{36}\.edits\.cipher$').hasMatch(name)){
      throw const FormatException('Invalid edit file.');
    }
    final file=File('${(await _root(owner)).path}/$name');
    if(!await file.exists()||await file.length()>maxRecipeBytes)throw const FormatException('Edit checkpoint unavailable.');
    final key=base64Decode(descriptor['key'] as String);
    final nonce=base64Decode(descriptor['nonce'] as String);
    final mac=base64Decode(descriptor['mac'] as String);
    if(key.length!=32||nonce.length!=12||mac.length!=16)throw const FormatException('Invalid edit key.');
    final plain=await AesGcm.with256bits().decrypt(SecretBox(await file.readAsBytes(),nonce:nonce,mac:Mac(mac)),
      secretKey:SecretKey(key),aad:utf8.encode('orbit-m23-edits-v1|$owner|${data['id']}'));
    final decoded=jsonDecode(utf8.decode(plain));
    if(decoded is! Map)throw const FormatException('Invalid edit recipe.');
    return Map<String,dynamic>.from(decoded);
  }
  Future<void> _deleteEditBlob(String owner,Object? descriptor) async {
    if(descriptor is! Map)return;
    final name=descriptor['name'];
    if(name is String&&RegExp(r'^[a-fA-F0-9-]{36}\.edits\.cipher$').hasMatch(name)){
      final file=File('${(await _root(owner)).path}/$name');
      if(await file.exists())await file.delete();
    }
  }
  Future<void> saveEdits(String clientId,Map<String,Object?> changes) async {
    final owner=await _account();
    final snapshot=jsonDecode(jsonEncode(changes)) as Map<String,dynamic>;
    await _serialize(() async {
      if(await _owner()!=owner)return;
      final data=await _metadata(owner);
      if(data==null||data['id']!=clientId)return;
      final saved=DateTime.tryParse(data['saved_at'] as String? ?? '');
      if(saved==null||DateTime.now().toUtc().difference(saved)>maxAge)return;
      final previous=await _readEdits(owner,data);
      final edits=<String,Object?>{...previous,...snapshot};
      final bytes=utf8.encode(jsonEncode(edits));
      if(bytes.length>maxRecipeBytes)throw const FormatException('Capture edit recipe too large.');
      final key=_crypto.randomBytes(32),nonce=_crypto.randomBytes(12);
      final box=await AesGcm.with256bits().encrypt(bytes,secretKey:SecretKey(key),nonce:nonce,
        aad:utf8.encode('orbit-m23-edits-v1|$owner|$clientId'));
      final name=const Uuid().v4()+'.edits.cipher';
      final file=File('${(await _root(owner)).path}/$name');
      try{
        await file.writeAsBytes(box.cipherText,flush:true);
        if(await _owner()!=owner){await file.delete();return;}
        final next=Map<String,dynamic>.from(data)..remove('edits');
        next['edit_blob']={'name':name,'key':base64Encode(key),'nonce':base64Encode(nonce),'mac':base64Encode(box.mac.bytes)};
        await _vault.write(_index(owner),jsonEncode(next));
      }catch(_){if(await file.exists())await file.delete();rethrow;}
      await _deleteEditBlob(owner,data['edit_blob']);
    });
  }

  Future<String> _account() async {
    final value=await _owner();
    if(value==null||value.isEmpty)throw StateError('Orbit sign-in required.');
    return value;
  }

  String _index(String owner)=>'orbit.m7.capture.$owner';

  Future<Directory> _root(String owner) async {
    final base=await _support();
    final safe=owner.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'),'_');
    final dir=Directory('${base.path}/orbit-m7-encrypted-capture/$safe');
    await dir.create(recursive:true);
    return dir;
  }

  Future<Map<String,dynamic>?> _metadata(String owner) async {
    final data=await _vault.read(_index(owner));
    if(data==null)return null;
    final decoded=jsonDecode(data);
    if(decoded is! Map)throw const FormatException('Invalid capture metadata.');
    return Map<String,dynamic>.from(decoded);
  }

  Future<String> savePhoto(Uint8List bytes) async {
    if(bytes.isEmpty||bytes.length>OrbitMediaFormat.imageLimit){
      throw const FormatException('Capture exceeds photo limit.');
    }
    final owner=await _account();
    return _serialize(() async {
    if(await _owner()!=owner)throw StateError('Account changed.');
    final id=const Uuid().v4();
    final root=await _root(owner);
    final target=File('${root.path}/$id.cipher');
    final sealed=await _crypto.sealBytes(bytes,destination:target,
      ownerId:owner,transferId:id,purpose:'moment',variant:'capture');
    await _commit(owner,sealed,'image',null);
    return id;
    });
  }

  Future<String> saveClip(File source,{
    required String kind,required int durationMs,
  }) async {
    if(!const {'video','audio'}.contains(kind) ||
        durationMs<=0||durationMs>60000){
      throw const FormatException('Invalid captured clip.');
    }
    final owner=await _account();
    return _serialize(() async {
    if(await _owner()!=owner)throw StateError('Account changed.');
    final id=const Uuid().v4();
    final root=await _root(owner);
    final target=File('${root.path}/$id.cipher');
    final sealed=await _crypto.sealFile(source,destination:target,
      ownerId:owner,transferId:id,purpose:'moment',
      variant:'capture',maxInputBytes:kind=='video'
        ? OrbitMediaFormat.videoLimit:OrbitMediaFormat.audioLimit);
    await _commit(owner,sealed,kind,durationMs);
    return id;
    });
  }

  Future<void> _commit(String owner,OrbitSealedMedia media,
      String kind,int? duration) async {
    if(await _owner()!=owner){await media.file.delete();throw StateError('Account changed.');}
    final previous=await _metadata(owner);
    final metadata=<String,Object?>{
      'id':media.transferId,
      'name':media.transferId+'.cipher',
      'kind':kind,
      'duration_ms':duration,
      'plain_bytes':media.plainBytes,
      'cipher_bytes':media.bytes,
      'sha256':media.sha256,
      'key':base64Encode(media.key),
      'prefix':base64Encode(media.noncePrefix),
      'saved_at':DateTime.now().toUtc().toIso8601String(),
    };
    try {
      // Publication of a new index happens AFTER ciphertext is flushed.
      await _vault.write(_index(owner),jsonEncode(metadata));
    }catch(_){
      if(await media.file.exists())await media.file.delete();
      rethrow;
    }
    await _deleteEditBlob(owner,previous?['edit_blob']);
    final oldName=previous?['name'];
    if(oldName is String && RegExp(r'^[a-fA-F0-9-]{36}\.cipher$').hasMatch(oldName)
        && oldName!=metadata['name']){
      final old=File('${(await _root(owner)).path}/$oldName');
      if(await old.exists())await old.delete();
    }
  }

  /// Detect an encrypted M7 draft without decrypting it or changing the camera view.
  Future<bool> hasRecoverableDraft()=>_serialize(_hasRecoverableDraft);
  Future<bool> _hasRecoverableDraft() async {
    final owner = await _account();
    final data = await _metadata(owner);
    if (data == null){await _sweepCipherOrphans(owner,{});return false;}
    final saved = DateTime.tryParse(data['saved_at'] as String? ?? '');
    final now = DateTime.now().toUtc();
    if (saved == null || now.difference(saved.toUtc()) > maxAge ||
        saved.toUtc().isAfter(now.add(const Duration(minutes: 5)))) {
      await _purge(owner);
      return false;
    }
    final name = data['name'];
    if (name is! String || !name.endsWith('.cipher') ||
        name.contains('/') || name.contains('\\')) return false;
    final root = await _root(owner);
    final edits=data['edit_blob'];
    await _sweepCipherOrphans(owner,{name,if(edits is Map&&edits['name'] is String)edits['name'] as String});
    return File(root.path + '/' + name).exists();
  }
  Future<void> _sweepCipherOrphans(String owner,Set<String> keep) async{
    final root=await _root(owner);
    await for(final entry in root.list(followLinks:false)){
      final name=entry.uri.pathSegments.last;
      if(entry is File&&RegExp(r'^[a-fA-F0-9-]{36}(\.edits)?\.cipher$').hasMatch(name)&&!keep.contains(name)){
        await entry.delete();
      }
    }
  }
  Future<OrbitRecoveredMomentCapture?> restore()=>_serialize(_restore);
  Future<OrbitRecoveredMomentCapture?> _restore() async {
    final owner=await _account();
    final data=await _metadata(owner);
    if(data==null)return null;
    final timestamp=DateTime.tryParse(data['saved_at'] as String? ?? '');
    if(timestamp==null ||
        DateTime.now().toUtc().difference(timestamp.toUtc())>maxAge ||
        timestamp.toUtc().isAfter(DateTime.now().toUtc().add(
          const Duration(minutes:5)))){
      await _purge(owner);
      return null;
    }
    final name=data['name'];
    final id=data['id'];
    final kind=data['kind'];
    if(name is! String || id is! String ||
       !RegExp(r'^[a-fA-F0-9-]{36}\.cipher$').hasMatch(name) ||
       !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id) ||
       !['image','video','audio'].contains(kind)){
      throw const FormatException('Untrusted encrypted capture index.');
    }
    final file=File('${(await _root(owner)).path}/$name');
    if(!await file.exists() ||
       await file.length()!=data['cipher_bytes']){
      throw const FileSystemException('Encrypted capture is unavailable.');
    }
    final checksum=await hashes.sha256.bind(file.openRead()).first;
    if(checksum.toString()!=data['sha256']){
      throw StateError('Encrypted capture integrity mismatch.');
    }
    final key=Uint8List.fromList(base64Decode(data['key'] as String));
    final prefix=Uint8List.fromList(base64Decode(data['prefix'] as String));
    final bytes=(data['plain_bytes'] as num).toInt();
    if(key.length!=32 || prefix.length!=8 || bytes<=0 ||
       bytes>(kind=='video'?OrbitMediaFormat.videoLimit:
         kind=='audio'?OrbitMediaFormat.audioLimit:OrbitMediaFormat.imageLimit)){
      throw const FormatException('Invalid encrypted capture key.');
    }
    final sealed=OrbitSealedMedia(file:file,key:key,noncePrefix:prefix,
      plainBytes:bytes,bytes:(data['cipher_bytes'] as num).toInt(),
      sha256:data['sha256'] as String,ownerId:owner,transferId:id,
      purpose:'moment',variant:'capture');
    final edits=await _readEdits(owner,data);
    if(kind=='image'){
      final photo=await _crypto.openInMemory(
        await file.readAsBytes(),key:key,noncePrefix:prefix,
        ownerId:owner,transferId:id,purpose:'moment',
        variant:'capture',maxPlainBytes:OrbitMediaFormat.imageLimit);
      if(await _owner()!=owner)throw StateError('Account changed.');
      return OrbitRecoveredMomentCapture(
        kind:'image',clientId:id,photo:photo,edits:edits);
    }
    final temporary=await _temporary();
    final target=File('${temporary.path}/orbit-m7-recovered-$id.'+
      (kind=='video'?'mp4':'m4a'));
    await _decryptClip(sealed,target);
    if(await _owner()!=owner){
      if(await target.exists())await target.delete();
      throw StateError('Account changed during capture recovery.');
    }
    return OrbitRecoveredMomentCapture(
      kind:kind,clientId:id,clip:target,
      durationMs:(data['duration_ms'] as num?)?.toInt(),edits:edits);
  }

  Future<void> _decryptClip(OrbitSealedMedia sealed,File target) async {
    final input=await sealed.file.open();
    final output=await target.open(mode:FileMode.write);
    final cipher=AesGcm.with256bits();
    try{
      var remaining=sealed.plainBytes;
      var part=0;
      while(remaining>0){
        final plainCount=min(OrbitMediaFormat.plainChunkBytes,remaining);
        final length=plainCount+OrbitMediaFormat.tagBytes;
        final encrypted=Uint8List(length);
        var position=0;
        while(position<length){
          final got=await input.readInto(encrypted,position,length);
          if(got<=0)throw const FormatException('Truncated encrypted capture.');
          position+=got;
        }
        final nonce=Uint8List(12)..setRange(0,8,sealed.noncePrefix);
        ByteData.sublistView(nonce).setUint32(8,part,Endian.big);
        final box=SecretBox(encrypted.sublist(0,plainCount),
          nonce:nonce,mac:Mac(encrypted.sublist(plainCount)));
        final decoded=await cipher.decrypt(box,
          secretKey:SecretKey(sealed.key),
          aad:utf8.encode('orbit-m6-v1|${sealed.ownerId}|${sealed.transferId}'
            '|moment|capture|$part'));
        await output.writeFrom(decoded);
        remaining-=plainCount;
        part++;
      }
    }catch(_){
      await output.close();
      if(await target.exists())await target.delete();
      rethrow;
    }finally{
      await input.close();
    }
    await output.close();
  }

  Future<void> clear() async => purge(await _account());
  Future<void> clearIfCurrent(String clientId) async {
    final owner=await _account();
    await _serialize(()async{
      if(await _owner()!=owner)return;
      final data=await _metadata(owner);
      if(data?['id']==clientId)await _purge(owner);
    });
  }

  /// Called by session revocation/account switch BEFORE owner credentials
  /// are removed; purge does not require a currently active session.
  Future<void> purge(String owner) async {
    if(owner.isEmpty)return;
    await _serialize(()=>_purge(owner));
  }
  Future<void> _purge(String owner) async {
    Map<String,dynamic>? metadata;
    try{metadata=await _metadata(owner);}catch(_){}
    await _vault.delete(_index(owner));
    final name=metadata?['name'];
    if(name is String && RegExp(r'^[a-fA-F0-9-]{36}\.cipher$').hasMatch(name)){
      final file=File('${(await _root(owner)).path}/$name');
      if(await file.exists())await file.delete();
    }
    // Purge orphan ciphertext under the account-specific application folder.
    final root=await _root(owner);
    if(await root.exists()){
      await for(final entry in root.list(followLinks:false)){
        if(entry is File&&entry.path.endsWith('.cipher'))await entry.delete();
      }
    }
    final id=metadata?['id'];
    if(id is String&&RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)){
      final tmp=await _temporary();
      for(final ext in ['mp4','m4a']){
        final clip=File('${tmp.path}/orbit-m7-recovered-$id.$ext');
        if(await clip.exists())await clip.delete();
      }
    }
  }
}
