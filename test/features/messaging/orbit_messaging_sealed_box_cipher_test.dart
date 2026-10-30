import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as sha;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_sealed_box_cipher.dart';

class _Device implements OrbitMessagingDeviceSource {
  _Device(this.owner,this.device);
  final String owner,device;
  @override
  Future<({String owner,String device})> current() async=>
    (owner:owner,device:device);
}
class _Store implements OrbitMessagingDeviceStore {
  final keys=<String,OrbitMessagingDeviceMaterial>{};
  final pins=<String,String>{};
  @override
  Future<OrbitMessagingDeviceMaterial?> read(String owner,String device) async=>
    keys[owner+'|'+device];
  @override
  Future<void> write(OrbitMessagingDeviceMaterial m) async {
    keys[m.owner+'|'+m.device]=m;
  }
  @override
  Future<void> pinIdentity(String owner,String peer,String device,String fp) async {
    final k=owner+'|'+peer+'|'+device;
    if(pins[k]!=null&&pins[k]!=fp)throw OrbitMessagingSecurityException(
      'Identity pin changed',409);
    pins[k]=fp;
  }
  @override
  Future<void> purge(String owner) async {
    keys.removeWhere((k,v)=>v.owner==owner);
    pins.removeWhere((k,v)=>k.startsWith(owner+'|'));
  }
}
class _Directory extends OrbitMessagingApi {
  _Directory(this.items);
  final Map<String,OrbitMessagingKeyDirectory> items;
  @override
  Future<OrbitMessagingKeyDirectory> discoverKeys(String user) async =>
    items[user]!;
}
OrbitMessagingKeyDirectory _directory(String user,String device,
    OrbitMessagingPublicKeyBundle b)=>OrbitMessagingKeyDirectory(user,[
      OrbitMessagingRemoteDevice(
        id:device,identity:b.identityEd25519,
        signedPrekey:b.signedPrekeyX25519,signature:b.signature,
        signedPrekeyId:b.signedPrekeyId,keyVersion:1,
        fingerprint:sha.sha256.convert(utf8.encode(b.identityEd25519)).toString(),
      ),
    ]);

void main(){
  test('Signed ECIES envelopes encrypt for multiple devices, bind epoch and reject tampering',
      () async {
    final memory=_Store();
    final directories=<String,OrbitMessagingKeyDirectory>{};
    final api=_Directory(directories);
    final alice=OrbitMessagingSealedBoxCipher(
      source:_Device('alice','a-device'),store:memory,api:api);
    final bob=OrbitMessagingSealedBoxCipher(
      source:_Device('bob','b-device'),store:memory,api:api);
    final a=await alice.setupDevice(),b=await bob.setupDevice();
    directories['alice']=_directory('alice','a-device',a);
    directories['bob']=_directory('bob','b-device',b);
    expect(alice.independentlyVerified,false);
    expect(a.signature,isNotEmpty);
    final encrypted=await alice.encrypt(
      conversationId:'conversation-uuid',groupEpoch:5,kind:'text',
      plaintext:Uint8List.fromList(utf8.encode('secret message')),
      recipients:directories);
    expect(encrypted.envelopes.length,2);
    final recipient=encrypted.envelopes.singleWhere((e)=>e.deviceId=='b-device');
    expect(recipient.ciphertextB64, isNot(contains('secret message')));
    final envelope=OrbitMailboxEnvelope(
      id:'envelope',messageId:'message',senderId:'alice',
      senderDeviceId:'a-device',kind:'text',
      protocol:encrypted.protocol,groupEpoch:5,keyVersion:1,
      ciphertextB64:recipient.ciphertextB64,
      headerB64:recipient.headerB64,
      createdAt:DateTime.utc(2026,10,30));
    expect(utf8.decode(await bob.decrypt(
      envelope:envelope,conversationId:'conversation-uuid')),'secret message');
    await expectLater(bob.decrypt(
      envelope:envelope,conversationId:'different-conversation'),
      throwsA(isA<OrbitMessagingSecurityException>()));
    final corrupted=OrbitMailboxEnvelope(
      id:'new',messageId:'new',senderId:'alice',
      senderDeviceId:'a-device',kind:'text',
      protocol:encrypted.protocol,groupEpoch:6,keyVersion:1,
      ciphertextB64:recipient.ciphertextB64,
      headerB64:recipient.headerB64,
      createdAt:DateTime.utc(2026,10,30));
    await expectLater(bob.decrypt(
      envelope:corrupted,conversationId:'conversation-uuid'),
      throwsA(isA<OrbitMessagingSecurityException>()));
    final badSignature=OrbitMessagingRemoteDevice(
      id:'a-device',identity:a.identityEd25519,
      signedPrekey:a.signedPrekeyX25519,
      signedPrekeyId:a.signedPrekeyId,keyVersion:1,
      signature:base64Encode(List<int>.filled(64,7)),
      fingerprint:sha.sha256.convert(
        utf8.encode(a.identityEd25519)).toString());
    await expectLater(bob.verifyPeerIdentity(
      OrbitMessagingKeyDirectory('alice',[badSignature])),
      throwsA(isA<OrbitMessagingSecurityException>()));
    await bob.purgeForOwner('bob');
    await expectLater(bob.decrypt(
      envelope:envelope,conversationId:'conversation-uuid'),
      throwsA(isA<OrbitMessagingSecurityException>()));
  });

  test('Key setup is stable and signing contract never exports private keys',
      () async {
    final store=_Store();
    final crypto=OrbitMessagingSealedBoxCipher(
      source:_Device('owner','device-1'),store:store,
      api:_Directory({}));
    final first=await crypto.setupDevice();
    final second=await crypto.setupDevice();
    expect(first.toJson(),second.toJson());
    final registered=first.toJson().toString();
    expect(registered, isNot(contains('private')));
    expect(store.keys.length,1);
  });
}
