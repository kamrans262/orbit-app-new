import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../media/data/orbit_media_repository.dart';
import 'orbit_location_models.dart';
import 'orbit_location_repository.dart';

/// Gives only explicitly selected M10 person recipients decryptable M6 avatar
/// envelopes. No public image URL, plaintext upload or persistent key cache.
class OrbitLocationAvatarGrantService {
  OrbitLocationAvatarGrantService({OrbitIdentityClient? identity,
    OrbitMediaRepository? media,OrbitMediaCrypto? crypto,
    OrbitLocationRepository? location})
      :_identity=identity??OrbitIdentityClient.instance,
       _media=media??OrbitMediaRepository(),
       _crypto=crypto??OrbitMediaCrypto(),
       _location=location??OrbitLocationRepository();

  final OrbitIdentityClient _identity;
  final OrbitMediaRepository _media;
  final OrbitMediaCrypto _crypto;
  final OrbitLocationRepository _location;

  Future<String?> currentPrivateAvatarId() async {
    final profile=await _identity.profile();
    final id=profile['avatar_media_id'];
    return id is String && id.length==36 && profile['_offline_cached']!=true
        ?id:null;
  }

  Future<void> shareWithFriend(OrbitLocationShare share,String friendId) async {
    if(share.audienceType!='person'||share.audienceId!=friendId||
       !share.active)throw const FormatException('Invalid avatar audience.');
    final mediaId=await currentPrivateAvatarId();
    if(mediaId==null)throw StateError('No private profile photo was available.');
    final device=await _identity.trustedMediaDevice();
    final reference=Uri.encodeComponent(mediaId);
    final envelope=await _media.control('GET','/media/'+reference+
      '/key-envelope?device_id='+Uri.encodeComponent(device.id)+
      '&variant=original');
    final encrypted=envelope['wrapped_key_ciphertext'];
    if(encrypted is! String)throw const FormatException('Missing owner avatar envelope.');
    final key=await _crypto.unwrapKey(encrypted,
      privateKey:device.privateKey,publicKey:device.publicKey);
    if(key.owner!=await _identity.currentLocalSocialOwner()||
       key.purpose!='avatar'||key.variant!='original') {
      throw const FormatException('Avatar key ownership mismatch.');
    }
    final recipients=await _media.control('POST','/media/recipient-keys',body:{
      'audience_kind':'selected_friends','recipient_ids':[friendId],
    });
    final rows=recipients['recipients'];
    if(rows is! List || rows.length!=1 || rows.first is! Map ||
       (rows.first as Map)['recipient_id']!=friendId) {
      throw const FormatException('Recipient encryption keys unavailable.');
    }
    final devices=(rows.first as Map)['devices'];
    if(devices is! List||devices.isEmpty||devices.length>100){
      throw const FormatException('No approved recipient device.');
    }

    // Only wrap the decrypted content key; NEVER reupload a plaintext avatar.
    final sealed=OrbitSealedMedia(file:File(''),key:key.key,
      noncePrefix:Uint8List.fromList(key.prefix),plainBytes:key.length,
      bytes:0,sha256:'',ownerId:key.owner,transferId:key.transfer,
      purpose:key.purpose,variant:key.variant);
    final grants=<Map<String,Object?>>[];
    for(final candidate in devices){
      if(candidate is! Map)throw const FormatException('Malformed device.');
      final deviceId=candidate['device_id'];
      final encoded=candidate['public_key'];
      if(deviceId is! String||encoded is! String) {
        throw const FormatException('Missing device key.');
      }
      final publicKey=base64Decode(encoded);
      if(publicKey.length!=32)throw const FormatException('Invalid device key.');
      grants.add({
        'device_id':deviceId,'variant':'original','key_version':'v1',
        'algorithm':OrbitMediaFormat.envelopeAlgorithm,
        'wrapped_key_ciphertext':await _crypto.wrapKey(sealed,publicKey),
      });
    }

    String? grantId;
    try {
      final ids=await _media.createGrants(mediaId,
        audience:'selected_friends',recipients:[friendId],
        keyEnvelopes:grants,idempotencyKey:const Uuid().v4(),
        expiresAt:share.expiresAt);
      if(ids.length!=1)throw StateError('Avatar grant not verified.');
      grantId=ids.single;
      await _location.attachAvatar(shareId:share.id,
        mediaId:mediaId,grantId:grantId);
    }catch(_){
      // If M10 binding fails, revoke any created M6 envelope; never leave
      // an unlinked independent photo audience.
      if(grantId!=null){
        try {
          await _identity.socialRequest('DELETE','/media/'+reference+
            '/grants/'+Uri.encodeComponent(grantId));
        }catch(_){}
      }
      rethrow;
    } finally {
      // Key material is ephemeral; no disk storage, network logs or cache.
      key.key.fillRange(0,key.key.length,0);
    }
  }
}
