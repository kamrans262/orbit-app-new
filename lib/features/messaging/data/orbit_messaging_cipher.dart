import 'dart:typed_data';
import 'orbit_messaging_models.dart';

/// Integrate a vetted, licensed Double Ratchet + group sender-key implementation.
///
/// CRITICAL: Every cipher call must commit ratchet writes durably before its
/// ciphertext is released, serialize per remote device address, and pin
/// remote identity fingerprints. Never reset sessions because decryption fails.
///
/// Do not use the earlier M6 media X25519 key as a messaging identity.
/// The Stage 2 server uses a separate Ed25519-signing public directory.
/// Protocol compatibility and AGPL/GPL obligations need review before launch.
abstract class OrbitMessagingCipher {
  bool get independentlyVerified;
  String get protocol;
  Future<OrbitMessagingPublicKeyBundle> setupDevice();
  Future<void> verifyPeerIdentity(OrbitMessagingKeyDirectory peer);
  Future<OrbitEncryptedSend> encrypt({
    required String conversationId,
    required int groupEpoch,
    required String kind,
    required Uint8List plaintext,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  });
  Future<Uint8List> decrypt({
    required OrbitMailboxEnvelope envelope,
    required String conversationId,
  });
  Future<void> purgeForOwner(String owner);
}

/// No mock AES key-exchange, plaintext upload or false Signal branding.
/// Screens can load authorized conversation metadata while disabled.
class OrbitUnconfiguredMessagingCipher implements OrbitMessagingCipher {
  const OrbitUnconfiguredMessagingCipher();
  static const unavailable='Secure messaging is not yet ready on this device. '
      'Messages cannot be sent or decrypted until E2EE setup is verified.';
  @override
  bool get independentlyVerified=>false;
  @override
  String get protocol=>'unavailable';
  Never _notReady()=>throw OrbitMessagingSecurityException(unavailable,503);
  @override
  Future<OrbitMessagingPublicKeyBundle> setupDevice() async =>_notReady();
  @override
  Future<void> verifyPeerIdentity(OrbitMessagingKeyDirectory peer) async=>_notReady();
  @override
  Future<OrbitEncryptedSend> encrypt({
    required String conversationId,required int groupEpoch,
    required String kind,required Uint8List plaintext,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  }) async=>_notReady();
  @override
  Future<Uint8List> decrypt({
    required OrbitMailboxEnvelope envelope,required String conversationId,
  }) async=>_notReady();
  @override
  Future<void> purgeForOwner(String owner) async {}
}

/// Envelope bytes must be committed by the ratchet engine first.
/// A stable client_id is persisted and reused for ambiguous HTTP retries.
class OrbitEncryptedSend {
  const OrbitEncryptedSend({required this.protocol,required this.kind,
    required this.groupEpoch,required this.envelopes});
  final String protocol,kind;
  final int groupEpoch;
  final List<OrbitCipherEnvelope> envelopes;
}
