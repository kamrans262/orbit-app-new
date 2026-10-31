import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../circles/data/orbit_circle_repository.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../media/data/orbit_media_recipient_keys.dart';
import '../../media/data/orbit_media_repository.dart';
import 'orbit_messaging_api.dart';
import 'orbit_messaging_models.dart';

class OrbitEncryptedChatMedia {
  const OrbitEncryptedChatMedia({required this.mediaId,
    required this.kind,required this.mime,required this.durationMs});
  final String mediaId,kind,mime;
  final int? durationMs;
  String encode()=>jsonEncode({
    'v':1,'type':'orbit_m13_media','media_id':mediaId,
    'kind':kind,'mime':mime,
    if(durationMs!=null)'duration_ms':durationMs,
  });
  static OrbitEncryptedChatMedia? tryParse(String text){
    try{
      final value=jsonDecode(text);
      if(value is! Map||value['v']!=1||
          value['type']!='orbit_m13_media'||
          value['media_id'] is! String||
          !const ['image','voice','video'].contains(value['kind'])||
          value['mime'] is! String)return null;
      final id=value['media_id'] as String;
      if(!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id))return null;
      return OrbitEncryptedChatMedia(
        mediaId:id,kind:value['kind'] as String,
        mime:value['mime'] as String,
        durationMs:(value['duration_ms'] as num?)?.toInt());
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

  Future<OrbitEncryptedChatMedia> stage({
    required OrbitConversation conversation,
    required File original,
    required String kind,
    int? durationMs,
  }) async {
    // Opportunistic cleanup of orphaned encrypted uploads, never of user media.
    unawaited(pruneOrphanedCiphertext().catchError((_)=>0));
    if(!const ['image','voice','video'].contains(kind)){
      throw ArgumentError.value(kind,'kind','Unsupported encrypted media');
    }
    final current=await _identity.currentLocalSocialOwner();
    if(current==null)throw OrbitIdentityException('Sign in first.',401);
    final fresh=conversation.kind=='circle'
      ?await _api.circle(conversation.circleId!)
      :await _api.direct(conversation.peerId!);
    if(fresh.id!=conversation.id||fresh.groupEpoch!=conversation.groupEpoch){
      throw OrbitIdentityException('Conversation permissions changed.',409);
    }
    final byteCount=await original.length();
    final limit=switch(kind){
      'image'=>OrbitMediaFormat.imageLimit,
      'voice'=>OrbitMediaFormat.audioLimit,
      'video'=>OrbitMediaFormat.videoLimit,
      _=>0,
    };
    if((kind=='video' && (durationMs==null || durationMs<1 ||
        durationMs>60000)) || byteCount<=0||byteCount>limit){
      throw const FormatException('Media exceeds encrypted upload limit.');
    }
    final recipients=await _eligibleRecipients(fresh,current);
    final ownerDevices=await _keys.discover(audienceKind:'only_me',
      purpose:'message',recipientIds:[current]);
    final userDevices=<OrbitMediaRecipient>[];
    for(final peer in recipients){
      final people=await _keys.discover(
        audienceKind:fresh.kind=='circle'?'selected_circles':'selected_friends',
        purpose:'message',circleId:fresh.kind=='circle'?fresh.circleId:null,
        recipientIds:[peer]);
      userDevices.addAll(people);
    }
    final temp=await getTemporaryDirectory();
    final transfer=const Uuid().v4();
    final encrypted=File(temp.path+Platform.pathSeparator+
      'orbit_m13_'+transfer+'.cipher');
    OrbitSealedMedia? sealed;
    String mime;
    try{
      if(kind=='image'){
        // Remove EXIF, GPS and source metadata before encrypting bytes.
        final clean=OrbitMediaCrypto.preparePhoto(
          Uint8List.fromList(await original.readAsBytes()));
        sealed=await _crypto.sealBytes(clean.jpeg,
          destination:encrypted,ownerId:current,
          transferId:transfer,purpose:'message');
        mime='image/jpeg';
      }else{
        sealed=await _crypto.sealFile(original,
          destination:encrypted,ownerId:current,
          transferId:transfer,purpose:'message',maxInputBytes:limit);
        mime=kind=='voice'?'audio/mp4':'video/mp4';
      }
      final receipt=await _media.upload(sealed,
        kind:kind=='voice'?'audio':kind,mime:mime,
        durationMs:durationMs);
      if(!receipt.ready)throw StateError('Private ciphertext still verifying.');
      // First grant the sender their own other devices access. Otherwise
      // a restored or second device would have an unreadable sent item.
      final ownKeys=await _keys.encryptEnvelopes(sealed,ownerDevices);
      await _media.createGrants(receipt.mediaId,
        audience:'only_me',recipients:const [],
        keyEnvelopes:ownKeys,idempotencyKey:const Uuid().v4());
      final sharingKeys=await _keys.encryptEnvelopes(sealed,userDevices);
      await _media.createGrants(receipt.mediaId,
        audience:fresh.kind=='circle'?'selected_circles':'selected_friends',
        recipients:fresh.kind=='circle'?[fresh.circleId!]:recipients,
        keyEnvelopes:sharingKeys,idempotencyKey:const Uuid().v4());
      if(await _identity.currentLocalSocialOwner()!=current){
        throw OrbitIdentityException('Account changed during upload.',401);
      }
      return OrbitEncryptedChatMedia(
        mediaId:receipt.mediaId,kind:kind,mime:mime,durationMs:durationMs);
    }finally{
      if(await encrypted.exists())await encrypted.delete();
    }
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
    return _media.downloadPhoto(manifest.mediaId,deviceId:device.id,
      privateKey:device.privateKey,publicKey:device.publicKey,
      maxPlainBytes:switch(manifest.kind){
        'image'=>OrbitMediaFormat.imageLimit,
        'voice'=>OrbitMediaFormat.audioLimit,
        'video'=>64*1024*1024,
        _=>0,
      });
  }
}
