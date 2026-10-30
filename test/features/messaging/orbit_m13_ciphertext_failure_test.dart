import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_cipher.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_coordinator.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_local_vault.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

class _MailboxApi extends OrbitMessagingApi {
  bool markedDelivered=false;

  @override
  Future<String> get owner async=>'owner';

  @override
  Future<OrbitMessagingCapabilities> capabilities() async=>
    const OrbitMessagingCapabilities(
      available:true,e2eeClientVerified:true,circleEnabled:true,
      realtimeAvailable:false,pushAvailable:false);

  @override
  Future<OrbitEnvelopePage> sync(String conversation,{
    List<String> delivered=const [],int limit=100,
  }) async=>OrbitEnvelopePage([
    OrbitMailboxEnvelope(
      id:'envelope',messageId:'message',senderId:'peer',
      senderDeviceId:'device',kind:'text',protocol:'reviewed.v1',
      groupEpoch:1,keyVersion:1,ciphertextB64:'invalid',
      headerB64:'invalid',createdAt:DateTime.utc(2026),
    ),
  ],null);

  @override
  Future<void> delivered(String conversation,String id) async {
    markedDelivered=true;
  }
}

class _RejectingCipher extends OrbitUnconfiguredMessagingCipher {
  const _RejectingCipher();

  @override
  bool get independentlyVerified=>true;

  @override
  Future<Uint8List> decrypt({
    required OrbitMailboxEnvelope envelope,
    required String conversationId,
  }) async {
    throw OrbitMessagingSecurityException('Bad authentication tag',409);
  }
}

class _NoPersistenceVault extends OrbitMessagingLocalVault {
  bool stored=false;

  @override
  Future<bool> hasMessage(String conversation,String messageId) async=>false;

  @override
  Future<void> saveDecrypted(OrbitLocalDecryptedMessage message) async {
    stored=true;
  }
}

void main(){
  test('Unauthenticated ciphertext is surfaced, never acknowledged or cached',
      () async {
    final api=_MailboxApi();
    final vault=_NoPersistenceVault();
    final coordinator=OrbitMessagingCoordinator(
      api:api,cipher:const _RejectingCipher(),vault:vault);
    final thread=OrbitConversation(
      id:'conversation',kind:'direct',groupEpoch:1,peerId:'peer',
      createdAt:DateTime.utc(2026));
    await expectLater(coordinator.refresh(thread),
      throwsA(isA<OrbitMessagingSecurityException>()));
    expect(api.markedDelivered,isFalse);
    expect(vault.stored,isFalse);
  });
}
