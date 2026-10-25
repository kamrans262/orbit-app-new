import 'dart:convert';
import 'dart:typed_data';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_media_crypto.dart';

class OrbitMediaRecipientDevice {
  const OrbitMediaRecipientDevice(this.id,this.publicKey);
  final String id;
  final Uint8List publicKey;
}

class OrbitMediaRecipient {
  const OrbitMediaRecipient(this.userId,this.devices);
  final String userId;
  final List<OrbitMediaRecipientDevice> devices;
}

/// Query trusted public keys only for explicit accepted Friends or
/// server-approved Circle membership. Never cache roster or device keys as
/// authorization: re-fetch immediately before each sensitive grant.
class OrbitMediaRecipientKeys {
  OrbitMediaRecipientKeys({OrbitIdentityClient? identity,
      OrbitMediaCrypto? crypto})
    : _identity=identity??OrbitIdentityClient.instance,
      _crypto=crypto??OrbitMediaCrypto();
  final OrbitIdentityClient _identity;
  final OrbitMediaCrypto _crypto;

  Future<List<OrbitMediaRecipient>> discover({
    required String audienceKind, required List<String> recipientIds,
    String? circleId,
  }) async {
    if(!['only_me','selected_friends','selected_circles'].contains(audienceKind)
        || recipientIds.isEmpty || recipientIds.length>100
        || (audienceKind=='selected_circles' && circleId==null)) {
      throw ArgumentError('Invalid private media audience.');
    }
    final response=await _identity.socialRequest('POST','/media/recipient-keys',
      body:{
        'audience_kind':audienceKind,
        'recipient_ids':recipientIds,
        if(circleId!=null)'circle_id':circleId,
      });
    final data=response['data'];
    if(data is! Map || data['recipients'] is! List) {
      throw const FormatException('Recipient key response invalid.');
    }
    final found=<OrbitMediaRecipient>[];
    for(final raw in data['recipients'] as List) {
      if(raw is! Map || raw['recipient_id'] is! String ||
          raw['devices'] is! List) {
        throw const FormatException('Recipient keys invalid.');
      }
      final id=raw['recipient_id'] as String;
      if(!recipientIds.contains(id))throw StateError('Unexpected recipient.');
      final devices=<OrbitMediaRecipientDevice>[];
      for(final value in raw['devices'] as List) {
        if(value is! Map || value['device_id'] is! String ||
           value['public_key'] is! String)throw const FormatException('Bad device key.');
        final key=base64Decode(value['public_key'] as String);
        if(key.length!=32)throw const FormatException('Bad X25519 key length.');
        devices.add(OrbitMediaRecipientDevice(
          value['device_id'] as String,Uint8List.fromList(key)));
      }
      // Fail closed; every selected recipient must have at least one
      // verified trusted device so server can enforce delivery grants.
      if(devices.isEmpty)throw StateError('Recipient has no trusted device.');
      found.add(OrbitMediaRecipient(id,devices));
    }
    if(found.length!=recipientIds.toSet().length) {
      throw StateError('Some recipients became unavailable.');
    }
    return found;
  }

  Future<List<Map<String,Object?>>> encryptEnvelopes(
      OrbitSealedMedia sealed,List<OrbitMediaRecipient> people) async {
    final result=<Map<String,Object?>>[];
    for(final person in people) {
      for(final device in person.devices) {
        result.add({
          'device_id':device.id,'variant':sealed.variant,
          'key_version':'v1',
          'algorithm':OrbitMediaFormat.envelopeAlgorithm,
          'wrapped_key_ciphertext':await _crypto.wrapKey(sealed,device.publicKey),
        });
      }
    }
    return result;
  }
}
