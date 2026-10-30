import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_cipher.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_coordinator.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_local_vault.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

class _OutboundApi extends OrbitMessagingApi {
  int publishes=0;

  @override
  Future<String> get owner async=>'me';

  @override
  Future<OrbitMessagingCapabilities> capabilities() async=>
    const OrbitMessagingCapabilities(
      available:true,e2eeClientVerified:true,circleEnabled:true,
      realtimeAvailable:false,pushAvailable:false);

  @override
  Future<OrbitMessagingKeyDirectory> discoverKeys(String user,{
    bool consumeOneTimePrekey=true}) async=>
    OrbitMessagingKeyDirectory(user,[
      OrbitMessagingRemoteDevice(
        id:'device-$user',identity:'identity',signedPrekey:'prekey',
        signature:'signed',signedPrekeyId:1,keyVersion:1,
        fingerprint:'fingerprint',
      ),
    ]);

  @override
  Future<OrbitMessageAccepted> publish(String conversation,{
    required String clientId,required String kind,
    required String protocol,required int groupEpoch,
    required List<OrbitCipherEnvelope> envelopes}) async {
    publishes++;
    return OrbitMessageAccepted('server-$publishes',conversation,true,false);
  }
}

class _TransientApi extends _OutboundApi {
  _TransientApi(this.code);
  final int code;

  @override
  Future<OrbitMessageAccepted> publish(String conversation,{
    required String clientId,required String kind,
    required String protocol,required int groupEpoch,
    required List<OrbitCipherEnvelope> envelopes}) async {
    throw OrbitIdentityException('Transient messaging transport',code);
  }
}

class _CountingProvider extends OrbitUnconfiguredMessagingCipher {
  _CountingProvider();
  int currentlyEncrypting=0;
  int maxSimultaneous=0;

  @override
  bool get independentlyVerified=>true;

  @override
  String get protocol=>'reviewed.test';

  @override
  Future<void> verifyPeerIdentity(OrbitMessagingKeyDirectory peer) async {}

  @override
  Future<OrbitEncryptedSend> encrypt({
    required String conversationId,required int groupEpoch,
    required String kind,required Uint8List plaintext,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  }) async {
    currentlyEncrypting++;
    if(currentlyEncrypting>maxSimultaneous){
      maxSimultaneous=currentlyEncrypting;
    }
    try{
      await Future<void>.delayed(const Duration(milliseconds:12));
      return OrbitEncryptedSend(
        protocol:protocol,kind:kind,groupEpoch:groupEpoch,
        envelopes:[
          for(final directory in recipients.values)
            for(final device in directory.devices)
              OrbitCipherEnvelope(
                deviceId:device.id,ciphertextB64:'opaque',
                headerB64:'opaque-header'),
        ],
      );
    }finally{
      currentlyEncrypting--;
    }
  }
}

class _CiphertextVault extends OrbitMessagingLocalVault {
  final queued=<String>[];
  final acknowledged=<String>[];
  final previews=<OrbitLocalDecryptedMessage>[];

  @override
  Future<void> queue(OrbitQueuedCiphertext item,{
      OrbitLocalDecryptedMessage? preview}) async {
    queued.add(item.clientId);
    if(preview!=null)previews.add(preview);
  }

  @override
  Future<void> acknowledge(String clientId) async {
    acknowledged.add(clientId);
  }
}

void main(){
  test('Two simultaneous sends serialize their ratchet encryption state',() async {
    final api=_OutboundApi();
    final crypto=_CountingProvider();
    final vault=_CiphertextVault();
    final coordinator=OrbitMessagingCoordinator(
      api:api,cipher:crypto,vault:vault);
    final thread=OrbitConversation(
      id:'thread',kind:'direct',peerId:'peer',groupEpoch:1,
      createdAt:DateTime.utc(2026));

    final results=await Future.wait([
      coordinator.sendText(thread,'first'),
      coordinator.sendText(thread,'second'),
    ]);
    expect(results.every((r)=>r.accepted && !r.queued),isTrue);
    expect(crypto.maxSimultaneous,1);
    expect(api.publishes,2);
    expect(vault.queued,hasLength(2));
    expect(vault.acknowledged,hasLength(2));
  });
  test('HTTP 429/503 keep ciphertext and stable encrypted previews for retry',() async {
    for(final code in [429,503]){
      final api=_TransientApi(code);
      final vault=_CiphertextVault();
      final coordinator=OrbitMessagingCoordinator(
        api:api,cipher:_CountingProvider(),vault:vault);
      final thread=OrbitConversation(
        id:'thread-$code',kind:'direct',peerId:'peer',groupEpoch:1,
        createdAt:DateTime.utc(2026));
      final result=await coordinator.sendText(thread,'Offline private text');
      expect(result.accepted,isFalse);
      expect(result.queued,isTrue);
      expect(result.clientId,isNotEmpty);
      expect(vault.queued,[result.clientId]);
      expect(vault.acknowledged,isEmpty);
      expect(vault.previews,hasLength(1));
      expect(vault.previews.single.id,'local-'+result.clientId!);
      expect(vault.previews.single.text,'Offline private text');
    }
  });

}
