import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../circles/data/orbit_circle_repository.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../media/data/orbit_media_recipient_keys.dart';
import '../../media/data/orbit_media_repository.dart';
import 'orbit_messaging_api.dart';
import 'orbit_messaging_models.dart';

/// Key material is encoded ONLY inside the already-authenticated and
/// encrypted M13 message body or the device's encrypted local chat history.
/// Never put these values in server-visible metadata or an HTTP request.
class OrbitChatMediaContentKey {
  const OrbitChatMediaContentKey({
    required this.key,required this.noncePrefix,
    required this.owner,required this.transfer,
    required this.plainBytes,
  });
  final Uint8List key,noncePrefix;
  final String owner,transfer;
  final int plainBytes;

  factory OrbitChatMediaContentKey.fromSealed(OrbitSealedMedia media)=>
    OrbitChatMediaContentKey(key:media.key,
      noncePrefix:media.noncePrefix,owner:media.ownerId,
      transfer:media.transferId,plainBytes:media.plainBytes);

  Map<String,Object?> toJson()=>{
    'key_b64':base64Encode(key),'nonce_b64':base64Encode(noncePrefix),
    'owner_id':owner,'transfer_id':transfer,'plain_bytes':plainBytes,
    'purpose':'message','variant':'original',
  };

  static OrbitChatMediaContentKey parse(Map value){
    final key=base64Decode(value['key_b64'] as String);
    final nonce=base64Decode(value['nonce_b64'] as String);
    final owner=value['owner_id'];
    final transfer=value['transfer_id'];
    final size=value['plain_bytes'];
    if(key.length!=32||nonce.length!=8||
       owner is! String||owner.isEmpty||
       transfer is! String||
       !RegExp(r'^[a-f0-9-]{36}$').hasMatch(transfer)||
       size is! int||size<=0||size>OrbitMediaFormat.videoLimit||
       value['purpose']!='message'||value['variant']!='original') {
      throw const FormatException('Invalid E2EE chat attachment key.');
    }
    return OrbitChatMediaContentKey(key:Uint8List.fromList(key),
      noncePrefix:Uint8List.fromList(nonce),owner:owner,
      transfer:transfer,plainBytes:size);
  }
}

class OrbitEncryptedChatMedia {
  const OrbitEncryptedChatMedia({
    required this.mediaId,required this.kind,
    required this.mime,required this.durationMs,this.contentKey,
  });
  final String mediaId,kind,mime;
  final int? durationMs;
  final OrbitChatMediaContentKey? contentKey;

  String encode()=>jsonEncode({
    'v':contentKey==null?1:2,
    'type':'orbit_m13_media','media_id':mediaId,
    'kind':kind,'mime':mime,
    if(durationMs!=null)'duration_ms':durationMs,
    if(contentKey!=null)'content_key':contentKey!.toJson(),
  });

  static OrbitEncryptedChatMedia? tryParse(String text){
    try{
      final value=jsonDecode(text);
      if(value is! Map ||
          (value['v']!=1 && value['v']!=2) ||
          value['type']!='orbit_m13_media'||
          value['media_id'] is! String||
          !const ['image','voice','video'].contains(value['kind'])||
          value['mime'] is! String)return null;
      final id=value['media_id'] as String;
      if(!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id))return null;
      final version=value['v'] as int;
      if(version==1 && value.containsKey('content_key'))return null;
      if(version==2 && value['content_key'] is! Map)return null;
      final contentKey=version==2
        ?OrbitChatMediaContentKey.parse(value['content_key'] as Map)
        :null;
      return OrbitEncryptedChatMedia(
        mediaId:id,kind:value['kind'] as String,
        mime:value['mime'] as String,
        durationMs:(value['duration_ms'] as num?)?.toInt(),
        contentKey:contentKey);
    }catch(_){return null;}
  }
}

/// Existing M6 Hostinger-private ciphertext transfer plus M13-specific
/// message consent. No readable binary, public URL or file key enters chat
/// metadata: only the server-issued opaque media ID is E2EE-encrypted.
class OrbitMessagingMediaBridge {
  OrbitMessagingMediaBridge({OrbitMessagingApi? messaging,
    OrbitIdentityClient? identity,OrbitMediaCrypto? crypto,
    OrbitMediaRepository? media,OrbitMediaRecipientKeys? keys,
    OrbitCircleRepository? circles}):
      _api=messaging??OrbitMessagingApi(),
      _identity=identity??OrbitIdentityClient.instance,
      _crypto=crypto??OrbitMediaCrypto(),
      _media=media??OrbitMediaRepository(),
      _keys=keys??OrbitMediaRecipientKeys(),
      _circles=circles??OrbitCircleRepository();

  final OrbitMessagingApi _api;
  final OrbitIdentityClient _identity;
  final OrbitMediaCrypto _crypto;
  final OrbitMediaRepository _media;
  final OrbitMediaRecipientKeys _keys;
  final OrbitCircleRepository _circles;

  /// Delete only orphaned M13 ciphertext files after 90 days. Never inspect
  /// unrelated local files or user media. Decrypted media remains memory-only.
  static Future<int> pruneOrphanedCiphertext({
      Directory? tempDirectory,DateTime? now}) async{
    final temp=tempDirectory??await getTemporaryDirectory();
    if(!await temp.exists())return 0;
    final cutoff=(now??DateTime.now()).subtract(
      const Duration(days:90));
    final owned=RegExp(
      r'^orbit_m13_[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-'
      r'[a-f0-9]{4}-[a-f0-9]{12}\.cipher$');
    var deleted=0;
    await for(final item in temp.list(followLinks:false)){
      if(item is! File)continue;
      final name=item.uri.pathSegments.last;
      if(!owned.hasMatch(name))continue;
      try{
        final stat=await item.stat();
        if(stat.type==FileSystemEntityType.file &&
            stat.modified.isBefore(cutoff)){
          await item.delete();
          deleted++;
        }
      }on FileSystemException{
        // A concurrent OS temporary-file cleanup is not a chat failure.
      }
    }
    return deleted;
  }

  static const _pendingPrefix='orbit.m13.encryptedUpload.v1.';
  static const FlutterSecureStorage _pendingStorage=FlutterSecureStorage();

  Future<Directory> _pendingDirectory() async {
    final home=await getApplicationSupportDirectory();
    final folder=Directory(home.path+Platform.pathSeparator+
      'orbit_m13_pending_ciphertext');
    if(!await folder.exists())await folder.create(recursive:true);
    return folder;
  }

  String _pendingIndex(String owner,String conversation,String kind,
      String source,int bytes,int modifiedMs,int? durationMs,
      String sourceSha256) =>
    _pendingPrefix+hashes.sha256.convert(utf8.encode(
      '$owner|$conversation|$kind|$source|$bytes|$modifiedMs|'
      '$durationMs|$sourceSha256')).toString();

  /// The ciphertext stays inside the application's private support directory.
  /// Its content key and resume metadata stay in OS secure storage. This is
  /// the same encrypted upload session across process death and file reselect.
  Future<OrbitSealedMedia?> _restore(String index,String owner,
      String conversation,int epoch,String kind,int? durationMs) async {
    final raw=await _pendingStorage.read(key:index);
    if(raw==null)return null;
    final value=Map<String,dynamic>.from(jsonDecode(raw) as Map);
    final transfer=value['transfer'];
    if(value['owner']!=owner||value['conversation']!=conversation||
       value['epoch']!=epoch||value['kind']!=kind||
       value['duration_ms']!=durationMs||
       transfer is! String ||
       !RegExp(r'^[a-f0-9-]{36}$').hasMatch(transfer)) {
      throw OrbitIdentityException(
        'Pending encrypted upload is no longer authorized.',409);
    }
    final filename='orbit_m13_'+transfer+'.cipher';
    final folder=await _pendingDirectory();
    final file=File(folder.path+Platform.pathSeparator+filename);
    final key=base64Decode(value['key_b64'] as String);
    final nonce=base64Decode(value['nonce_b64'] as String);
    final bytes=value['bytes'];
    final plainBytes=value['plain_bytes'];
    final expectedHash=value['sha256'];
    if(key.length!=32||nonce.length!=8||bytes is! int||bytes<17||
       plainBytes is! int||plainBytes<=0||
       expectedHash is! String||!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)||
       !await file.exists()||await file.length()!=bytes) {
      throw const FormatException('Pending encrypted media is invalid.');
    }
    final actual=await hashes.sha256.bind(file.openRead()).first;
    if(actual.toString()!=expectedHash){
      throw const FormatException('Pending ciphertext integrity failed.');
    }
    return OrbitSealedMedia(file:file,key:Uint8List.fromList(key),
      noncePrefix:Uint8List.fromList(nonce),plainBytes:plainBytes,
      bytes:bytes,sha256:expectedHash,ownerId:owner,
      transferId:transfer,purpose:'message',variant:'original');
  }

  Future<void> _savePending(String index,OrbitSealedMedia sealed,
      String conversation,int epoch,String kind,int? durationMs) async {
    await _pendingStorage.write(key:index,value:jsonEncode({
      'owner':sealed.ownerId,'conversation':conversation,'epoch':epoch,
      'kind':kind,'duration_ms':durationMs,
      'transfer':sealed.transferId,'key_b64':base64Encode(sealed.key),
      'nonce_b64':base64Encode(sealed.noncePrefix),
      'bytes':sealed.bytes,'plain_bytes':sealed.plainBytes,
      'sha256':sealed.sha256,
      'created_at':DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<void> _discardPending(String index,OrbitSealedMedia sealed) async {
    await _pendingStorage.delete(key:index);
    if(await sealed.file.exists())await sealed.file.delete();
  }

  /// Remove only aged owned encrypted upload artifacts; never other files.
  /// Pending items are never discarded merely because a network retry fails.
  static Future<int> prunePendingCiphertext({DateTime? now}) async {
    final expiry=(now??DateTime.now()).toUtc().subtract(
      const Duration(days:90));
    final home=await getApplicationSupportDirectory();
    final root=Directory(home.path+Platform.pathSeparator+
      'orbit_m13_pending_ciphertext');
    final all=await _pendingStorage.readAll();
    var cleaned=0;
    for(final entry in all.entries) {
      if(!entry.key.startsWith(_pendingPrefix))continue;
      try{
        final data=Map<String,dynamic>.from(jsonDecode(entry.value) as Map);
        final created=DateTime.parse(data['created_at'] as String).toUtc();
        final transfer=data['transfer'];
        if(!created.isBefore(expiry)||transfer is! String||
           !RegExp(r'^[a-f0-9-]{36}$').hasMatch(transfer))continue;
        await _pendingStorage.delete(key:entry.key);
        final file=File(root.path+Platform.pathSeparator+
          'orbit_m13_'+transfer+'.cipher');
        if(await file.exists())await file.delete();
        cleaned++;
      }catch(_){ /* Never delete an unrecognized local file. */ }
    }
    // A process kill between sealing and the secure checkpoint can leave
    // unreferenced ciphertext. Only our exact owned file pattern is pruned.
    if(await root.exists()){
      final owned=RegExp(
        r'^orbit_m13_[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-'
        r'[a-f0-9]{4}-[a-f0-9]{12}\.cipher$');
      await for(final item in root.list(followLinks:false)){
        if(item is! File ||
           !owned.hasMatch(item.uri.pathSegments.last))continue;
        try{
          final stat=await item.stat();
          if(stat.type==FileSystemEntityType.file &&
             stat.modified.toUtc().isBefore(expiry)){
            await item.delete();
            cleaned++;
          }
        }on FileSystemException{ /* Best-effort owned-file cleanup. */ }
      }
    }
    return cleaned;
  }

  static Future<void> purgePendingForOwner(String owner) async {
    if(owner.isEmpty)return;
    final all=await _pendingStorage.readAll();
    final home=await getApplicationSupportDirectory();
    final root=Directory(home.path+Platform.pathSeparator+
      'orbit_m13_pending_ciphertext');
    for(final entry in all.entries) {
      if(!entry.key.startsWith(_pendingPrefix))continue;
      try{
        final data=Map<String,dynamic>.from(jsonDecode(entry.value) as Map);
        if(data['owner']!=owner)continue;
        await _pendingStorage.delete(key:entry.key);
        final transfer=data['transfer'];
        if(transfer is String &&
           RegExp(r'^[a-f0-9-]{36}$').hasMatch(transfer)){
          final file=File(root.path+Platform.pathSeparator+
            'orbit_m13_'+transfer+'.cipher');
          if(await file.exists())await file.delete();
        }
      }catch(_){ /* Preserve unrecognized local files. */ }
    }
  }

  Future<OrbitEncryptedChatMedia> _complete({
    required OrbitConversation conversation,
    required String owner,
    required OrbitSealedMedia sealed,
    required String pendingIndex,
    required String kind,
    required String mime,
    int? durationMs,
  }) async {
    final fresh=conversation.kind=='circle'
      ?await _api.circle(conversation.circleId!)
      :await _api.direct(conversation.peerId!);
    if(fresh.id!=conversation.id||fresh.groupEpoch!=conversation.groupEpoch ||
       sealed.ownerId!=owner||sealed.purpose!='message') {
      throw OrbitIdentityException('Conversation permissions changed.',409);
    }
    final recipients=await _eligibleRecipients(fresh,owner);
    final ownDevices=await _keys.discover(audienceKind:'only_me',
      purpose:'message',recipientIds:[owner]);
    final userDevices=<OrbitMediaRecipient>[];
    for(final peer in recipients) {
      userDevices.addAll(await _keys.discover(
        audienceKind:fresh.kind=='circle'?'selected_circles':'selected_friends',
        purpose:'message',
        circleId:fresh.kind=='circle'?fresh.circleId:null,
        recipientIds:[peer]));
    }
    final receipt=await _media.upload(sealed,
      kind:kind=='voice'?'audio':kind,mime:mime,durationMs:durationMs);
    if(!receipt.ready)throw StateError('Private ciphertext still verifying.');
    final ownKeys=await _keys.encryptEnvelopes(sealed,ownDevices);
    await _media.createGrants(receipt.mediaId,
      audience:'only_me',recipients:const [],
      keyEnvelopes:ownKeys,idempotencyKey:const Uuid().v4());
    final sharingKeys=await _keys.encryptEnvelopes(sealed,userDevices);
    await _media.createGrants(receipt.mediaId,
      audience:fresh.kind=='circle'?'selected_circles':'selected_friends',
      recipients:fresh.kind=='circle'?[fresh.circleId!]:recipients,
      keyEnvelopes:sharingKeys,idempotencyKey:const Uuid().v4());
    if(await _identity.currentLocalSocialOwner()!=owner) {
      throw OrbitIdentityException('Account changed during upload.',401);
    }
    final result=OrbitEncryptedChatMedia(
      mediaId:receipt.mediaId,kind:kind,mime:mime,durationMs:durationMs,
      contentKey:OrbitChatMediaContentKey.fromSealed(sealed));
    await _discardPending(pendingIndex,sealed);
    return result;
  }

  Future<OrbitEncryptedChatMedia> stage({
    required OrbitConversation conversation,
    required File original,
    required String kind,
    int? durationMs,
  }) async {
    unawaited(pruneOrphanedCiphertext().then<void>((_) {},
      onError:(_){ /* Best-effort old temp cleanup. */ }));
    unawaited(prunePendingCiphertext().then<void>((_) {},
      onError:(_){ /* Retain unrecognized pending uploads. */ }));
    if(!const ['image','voice','video'].contains(kind)) {
      throw ArgumentError.value(kind,'kind','Unsupported encrypted media');
    }
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw OrbitIdentityException('Sign in first.',401);
    final fresh=conversation.kind=='circle'
      ?await _api.circle(conversation.circleId!)
      :await _api.direct(conversation.peerId!);
    if(fresh.id!=conversation.id||fresh.groupEpoch!=conversation.groupEpoch){
      throw OrbitIdentityException('Conversation permissions changed.',409);
    }
    final stat=await original.stat();
    final bytes=stat.size;
    final limit=switch(kind){
      'image'=>OrbitMediaFormat.imageLimit,
      'voice'=>OrbitMediaFormat.audioLimit,
      'video'=>OrbitMediaFormat.videoLimit,
      _=>0,
    };
    if((kind=='video' && (durationMs==null || durationMs<1 ||
        durationMs>60000)) || bytes<=0||bytes>limit){
      throw const FormatException('Media exceeds encrypted upload limit.');
    }
    // The same path/size/mtime may be reused for different source bytes.
    // A content fingerprint prevents resuming the wrong ciphertext session.
    final sourceHash=(await hashes.sha256.bind(original.openRead()).first)
      .toString();
    final index=_pendingIndex(owner,conversation.id,kind,original.path,
      bytes,stat.modified.millisecondsSinceEpoch,durationMs,sourceHash);
    var sealed=await _restore(index,owner,conversation.id,
      conversation.groupEpoch,kind,durationMs);
    if(sealed==null) {
      final transfer=const Uuid().v4();
      final folder=await _pendingDirectory();
      final encrypted=File(folder.path+Platform.pathSeparator+
        'orbit_m13_'+transfer+'.cipher');
      try {
        if(kind=='image') {
          final clean=OrbitMediaCrypto.preparePhoto(
            Uint8List.fromList(await original.readAsBytes()));
          sealed=await _crypto.sealBytes(clean.jpeg,
            destination:encrypted,ownerId:owner,
            transferId:transfer,purpose:'message');
        }else{
          sealed=await _crypto.sealFile(original,
            destination:encrypted,ownerId:owner,
            transferId:transfer,purpose:'message',maxInputBytes:limit);
        }
        await _savePending(index,sealed,conversation.id,
          conversation.groupEpoch,kind,durationMs);
      }catch(_){
        if(await encrypted.exists())await encrypted.delete();
        rethrow;
      }
    }
    return _complete(conversation:conversation,owner:owner,sealed:sealed,
      pendingIndex:index,kind:kind,
      mime:kind=='image'?'image/jpeg':
        kind=='voice'?'audio/mp4':'video/mp4',durationMs:durationMs);
  }

  /// Retry unfinished encrypted uploads even when the original voice capture
  /// has been removed, without re-reading plaintext or generating new keys.
  /// Only the current authorized Circle epoch can complete the transfer.
  Future<List<OrbitEncryptedChatMedia>> resumePending(
      OrbitConversation conversation) async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)return const [];
    final records=await _pendingStorage.readAll();
    final recovered=<OrbitEncryptedChatMedia>[];
    for(final entry in records.entries){
      if(!entry.key.startsWith(_pendingPrefix))continue;
      try {
        final meta=Map<String,dynamic>.from(jsonDecode(entry.value) as Map);
        if(meta['owner']!=owner||
           meta['conversation']!=conversation.id)continue;
        final kind=meta['kind'] as String;
        final duration=meta['duration_ms'] as int?;
        final sealed=await _restore(entry.key,owner,conversation.id,
          conversation.groupEpoch,kind,duration);
        if(sealed==null)continue;
        recovered.add(await _complete(conversation:conversation,owner:owner,
          sealed:sealed,pendingIndex:entry.key,kind:kind,
          mime:kind=='image'?'image/jpeg':
            kind=='voice'?'audio/mp4':'video/mp4',durationMs:duration));
      }catch(_){
        // Leave ciphertext and its stable upload ID for a later authenticated
        // retry. Never claim successful delivery or reveal any private data.
      }
    }
    return recovered;
  }

  Future<List<String>> _eligibleRecipients(
      OrbitConversation thread,String owner) async {
    if(thread.kind=='direct'){
      final peer=thread.peerId;
      if(peer==null)throw OrbitIdentityException('Recipient unavailable.',409);
      // Eligibility lookup must not spend a one-time ratchet prekey.
      await _api.discoverKeys(peer,consumeOneTimePrekey:false);
      return [peer];
    }
    final circle=thread.circleId;
    if(circle==null)throw OrbitIdentityException('Circle unavailable.',409);
    final eligible=<String>[];
    for(var page=1;page<=10;page++){
      final result=await _circles.members(circle,page:page);
      for(final p in result.items){
        if(p.id==owner||p.role=='restricted')continue;
        try{
          await _api.discoverKeys(p.id,consumeOneTimePrekey:false);
          eligible.add(p.id);
        }on OrbitIdentityException catch(err){
          if(err.statusCode!=404)rethrow;
        }
      }
      if(!result.hasMore)break;
    }
    if(eligible.isEmpty){
      throw OrbitIdentityException('No consenting Circle recipients.',409);
    }
    return eligible;
  }

  Future<Uint8List> open(OrbitEncryptedChatMedia manifest) async {
    final device=await _identity.trustedMediaDevice();
    final maxBytes=switch(manifest.kind){
      'image'=>OrbitMediaFormat.imageLimit,
      'voice'=>OrbitMediaFormat.audioLimit,
      'video'=>64*1024*1024,
      _=>0,
    };
    final key=manifest.contentKey;
    if(key!=null){
      return _media.downloadMessageMedia(manifest.mediaId,
        deviceId:device.id,contentKey:key.key,noncePrefix:key.noncePrefix,
        ownerId:key.owner,transferId:key.transfer,
        purpose:'message',variant:'original',
        expectedPlainBytes:key.plainBytes,maxPlainBytes:maxBytes);
    }
    // Legacy v1 messages may still have an M6 device-wrapped key. New chat
    // attachments MUST use v2 with per-message content keys in the ratchet.
    return _media.downloadPhoto(manifest.mediaId,deviceId:device.id,
      privateKey:device.privateKey,publicKey:device.publicKey,
      maxPlainBytes:maxBytes);
  }
}
