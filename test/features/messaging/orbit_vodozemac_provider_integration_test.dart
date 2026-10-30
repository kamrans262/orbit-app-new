import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_sealed_box_cipher.dart'
    show OrbitMessagingDeviceSource;
import 'package:orbit_ui/features/messaging/data/orbit_messaging_vodozemac_cipher.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_vodozemac_ffi.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_vodozemac_store.dart';

class _Identity implements OrbitMessagingDeviceSource {
  _Identity(this.owner,this.device);
  final String owner,device;
  @override
  Future<({String owner,String device})> current() async =>
      (owner:owner,device:device);
}

Map<String,dynamic> _blank()=> <String,dynamic>{
  'v':1,'account':null,'public':null,'published':false,'next_prekey_id':25,
  'sessions_out':<String,dynamic>{},'sessions_in':<String,dynamic>{},
  'groups_out':<String,dynamic>{},'groups_in':<String,dynamic>{},
  'group_pending':<String,dynamic>{},'identity_pins':<String,dynamic>{},
  'decryption_pending':<String,dynamic>{},
  'processed_sender_keys':<String,dynamic>{},
};

class _MemoryRatchets extends OrbitVodozemacStateStore {
  final states=<String,Map<String,dynamic>>{};
  String key(String owner,String device)=>'$owner|$device';
  Map<String,dynamic> clone(Map<String,dynamic> data)=>
    Map<String,dynamic>.from(jsonDecode(jsonEncode(data)) as Map);

  @override
  Future<String> pickleKey(String owner,String device) async=>
    base64Encode(List<int>.generate(32,(i)=>i+1));

  @override
  Future<Map<String,dynamic>> read(String owner,String device) async=>
    clone(states[key(owner,device)]??_blank());

  @override
  Future<void> write(String owner,String device,
      Map<String,dynamic> value) async {
    states[key(owner,device)]=clone(value);
  }

  @override
  Future<void> purgeOwner(String owner) async {
    states.removeWhere((id,_)=>id.startsWith('$owner|'));
  }
}

class _Routing {
  final bundles=<String,OrbitMessagingPublicKeyBundle>{};
  final used=<String,int>{};
  final senderKeys=<String,List<OrbitSenderKeyEnvelope>>{};
  int nextId=0;

  OrbitMessagingKeyDirectory directory(String owner,{
    bool consume=false}) {
    final bundle=bundles[owner]!;
    final prekeys=bundle.oneTimePrekeys;
    final offset=used[owner]??0;
    final pre=consume && offset<prekeys.length?prekeys[offset]:null;
    if(pre!=null)used[owner]=offset+1;
    return OrbitMessagingKeyDirectory(owner,[
      OrbitMessagingRemoteDevice(
        id:'$owner-device',
        identity:bundle.identityEd25519,
        signedPrekey:bundle.signedPrekeyX25519,
        signature:bundle.signature,
        signedPrekeyId:bundle.signedPrekeyId,
        keyVersion:1,
        fingerprint:hashes.sha256.convert(
          utf8.encode(bundle.identityEd25519)).toString(),
        oneTimeKeyId:pre?.id,
        oneTimePublic:pre?.publicX25519,
      ),
    ]);
  }
  Map<String,OrbitMessagingKeyDirectory> roster(Iterable<String> users)=>
    {for(final user in users)user:directory(user)};
}

class _UserApi extends OrbitMessagingApi {
  _UserApi(this.routing,this.localUser);
  final _Routing routing;
  final String localUser;

  @override
  Future<Map<String,dynamic>> myDevices() async => {'devices':[{
    'id':'$localUser-device','trusted':true,
    'messaging_keys_registered':true,'available_one_time_prekeys':20,
  }]};

  @override
  Future<OrbitMessagingKeyDirectory> discoverKeys(String user,{
    bool consumeOneTimePrekey=true}) async=>
      routing.directory(user,consume:consumeOneTimePrekey);

  @override
  Future<OrbitMessagingKeyDirectory> claimDeviceKey(
      String user,String deviceId) async {
    final directory=routing.directory(user,consume:true);
    if(directory.devices.length!=1 ||
        directory.devices.single.id!=deviceId){
      throw OrbitMessagingSecurityException(
        'Cannot claim an unrelated device prekey.',409);
    }
    return directory;
  }

  @override
  Future<OrbitSenderKeySaved> distributeCircleSenderKey(
    String conversation,{
    required String clientId,required int groupEpoch,
    required String protocol,required List<OrbitCipherEnvelope> envelopes,
  }) async {
    for(final envelope in envelopes){
      routing.senderKeys.putIfAbsent(envelope.deviceId,()=>[]);
      routing.senderKeys[envelope.deviceId]!.add(OrbitSenderKeyEnvelope(
        id:'key-${++routing.nextId}',
        senderId:localUser,
        senderDeviceId:'$localUser-device',
        recipientKeyVersion:1,
        groupEpoch:groupEpoch,protocol:protocol,
        ciphertextB64:envelope.ciphertextB64,
        headerB64:envelope.headerB64,
      ));
    }
    return OrbitSenderKeySaved(clientId,groupEpoch,true);
  }

  @override
  Future<OrbitSenderKeyPage> circleSenderKeys(String conversation,{
    String? cursor,int limit=50}) async {
    // Current-epoch filtering is enforced by Laravel in production.
    final rows=routing.senderKeys['$localUser-device']??[];
    return OrbitSenderKeyPage(rows.toList(growable:false),null,
      rows.isEmpty?1:rows.last.groupEpoch);
  }
}

OrbitMailboxEnvelope _inbox(OrbitCipherEnvelope ciphertext,{
  required String id,required String sender,required String kind,
  required int epoch})=>OrbitMailboxEnvelope(
    id:'env-$id',messageId:id,senderId:sender,
    senderDeviceId:'$sender-device',
    kind:kind,protocol:OrbitMessagingVodozemacCipher.protocolName,
    groupEpoch:epoch,keyVersion:1,
    ciphertextB64:ciphertext.ciphertextB64,
    headerB64:ciphertext.headerB64,createdAt:DateTime.utc(2026,10,31),
  );

void main(){
  final native=OrbitVodozemacNative.tryLoad();
  final required=Platform.environment['ORBIT_M13_NATIVE_REQUIRED']=='1';

  test('Real Dart provider encrypts direct and Circle messages and rejects group replay',
    () async {
    final bridge=native!;
    final state=_MemoryRatchets();
    final routing=_Routing();
    final alice=OrbitMessagingVodozemacCipher(
      native:bridge,store:state,api:_UserApi(routing,'alice'),
      source:_Identity('alice','alice-device'));
    final bob=OrbitMessagingVodozemacCipher(
      native:bridge,store:state,api:_UserApi(routing,'bob'),
      source:_Identity('bob','bob-device'));
    routing.bundles['alice']=await alice.setupDevice();
    routing.bundles['bob']=await bob.setupDevice();

    final recipients=routing.roster(['alice','bob']);
    final direct=await alice.encrypt(
      conversationId:'private-conversation',groupEpoch:1,kind:'text',
      plaintext:Uint8List.fromList(utf8.encode('Hello Bob')),
      recipients:recipients);
    final forBob=direct.envelopes.singleWhere(
      (e)=>e.deviceId=='bob-device');
    final plain=await bob.decrypt(
      envelope:_inbox(forBob,id:'direct-1',sender:'alice',
        kind:'text',epoch:1),
      conversationId:'private-conversation');
    expect(utf8.decode(plain),'Hello Bob');
    await bob.confirmStoredDecryption('env-direct-1');

    await alice.prepareGroupEpoch(
      conversationId:'circle',groupEpoch:1,recipients:recipients);
    await bob.refreshGroupKeys('circle',1);
    final grouped=await alice.encrypt(
      conversationId:'circle',groupEpoch:1,kind:'text',
      plaintext:Uint8List.fromList(utf8.encode('Hello Circle')),
      recipients:recipients);
    final encrypted=grouped.envelopes.singleWhere(
      (e)=>e.deviceId=='bob-device');
    final envelope=_inbox(encrypted,id:'circle-message-1',
      sender:'alice',kind:'text',epoch:1);
    final groupText=await bob.decrypt(
      envelope:envelope,conversationId:'circle');
    expect(utf8.decode(groupText),'Hello Circle');
    await bob.confirmStoredDecryption(envelope.id);

    // A changed server envelope ID does not bypass Megolm's protected
    // ratchet-index replay fence in the encrypted device snapshot.
    final replay=_inbox(encrypted,id:'forged-replay',
      sender:'alice',kind:'text',epoch:1);
    await expectLater(
      bob.decrypt(envelope:replay,conversationId:'circle'),
      throwsA(isA<OrbitMessagingSecurityException>()));
    final stored=state.states['bob|bob-device']!;
    expect(stored['groups_in'],isNotEmpty);

    // A separate group epoch must have a fresh sender key and is not
    // decryptable by a removed device until explicitly authorized again.
    final prior=state.states['alice|alice-device']!;
    final oldSession=(prior['groups_out'] as Map)['circle']['session_id'];
    await alice.prepareGroupEpoch(
      conversationId:'circle',groupEpoch:2,recipients:recipients);
    final rotated=state.states['alice|alice-device']!;
    final newSession=(rotated['groups_out'] as Map)['circle']['session_id'];
    expect(newSession,isNot(oldSession));

    // The trusted signing identity may remain the same while its signed
    // Curve prekey or key version rotates. A separately verified acceptance
    // must clear the stale outbound Olm chain, never silently trust changes.
    final stale=state.states['alice|alice-device']!;
    final outgoing=stale['sessions_out'] as Map;
    final toBob=Map<String,dynamic>.from(outgoing['bob-device'] as Map);
    toBob['key_version']=0;
    outgoing['bob-device']=toBob;
    await state.write('alice','alice-device',stale);
    final fingerprint=routing.directory('bob').devices.single.fingerprint;
    await expectLater(alice.acceptVerifiedPeerIdentity(
      peerId:'bob',deviceId:'bob-device',
      verifiedFingerprint:List.filled(64,'0').join()),
      throwsA(isA<OrbitMessagingSecurityException>()));
    await alice.acceptVerifiedPeerIdentity(
      peerId:'bob',deviceId:'bob-device',
      verifiedFingerprint:fingerprint);
    final accepted=state.states['alice|alice-device']!;
    expect((accepted['sessions_out'] as Map).containsKey('bob-device'),
      isFalse);
    expect(accepted['groups_out'],isEmpty);
  },skip:native==null&&!required);
}
