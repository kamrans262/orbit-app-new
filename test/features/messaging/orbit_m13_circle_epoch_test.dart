import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_cipher.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_coordinator.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

class _ChangingCircle extends OrbitMessagingApi {
  @override
  Future<String> get owner async=>'owner';
  @override
  Future<OrbitMessagingCapabilities> capabilities() async=>
    const OrbitMessagingCapabilities(
      available:true,e2eeClientVerified:true,
      circleEnabled:true,realtimeAvailable:false,pushAvailable:false);
  @override
  Future<OrbitConversation> circle(String id) async=>
    OrbitConversation(id:'chat',circleId:id,kind:'circle',groupEpoch:8,
      createdAt:DateTime.utc(2026));
}
class _CountingCipher extends OrbitUnconfiguredMessagingCipher {
  _CountingCipher();
  bool encryptInvoked=false;
  @override
  bool get independentlyVerified=>true;
  @override
  Future<OrbitEncryptedSend> encrypt({
    required String conversationId,required int groupEpoch,
    required String kind,required Uint8List plaintext,
    required Map<String,OrbitMessagingKeyDirectory> recipients}) async {
    encryptInvoked=true;
    throw StateError('Encryption may not run after epoch change.');
  }
}
void main(){
  test('Circle membership/consent epoch change blocks encryption before device keys',() async{
    final cipher=_CountingCipher();
    final coordinator=OrbitMessagingCoordinator(
      api:_ChangingCircle(),cipher:cipher);
    final old=OrbitConversation(id:'chat',circleId:'circle',
      kind:'circle',groupEpoch:7,createdAt:DateTime.utc(2026));
    await expectLater(coordinator.sendEncrypted(old,kind:'text',
      data:Uint8List.fromList([65,66,67])),
      throwsA(isA<OrbitMessagingSecurityException>()));
    expect(cipher.encryptInvoked,isFalse);
  });
}
