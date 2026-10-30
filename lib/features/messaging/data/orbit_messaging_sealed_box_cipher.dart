import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_messaging_api.dart';
import 'orbit_messaging_cipher.dart';
import 'orbit_messaging_models.dart';

/// Authenticated ephemeral ECDH envelopes, with a separately signed device
/// directory. This is NOT Signal Double Ratchet. The crypto primitives are
/// standard, but this composition requires an independent protocol audit.
class OrbitMessagingSealedBoxCipher implements OrbitMessagingCipher {
  OrbitMessagingSealedBoxCipher({OrbitMessagingDeviceSource? source,
      OrbitMessagingDeviceStore? store,OrbitMessagingApi? api})
    : _source=source??OrbitLiveMessagingDeviceSource(),
      _store=store??OrbitPlatformMessagingDeviceStore(),
      _api=api??OrbitMessagingApi();

  static const signedContext='orbit-m13-signed-prekey-v1';
  static const suite='orbit-m13-ecies-ephemeral-v1';
  final OrbitMessagingDeviceSource _source;
  final OrbitMessagingDeviceStore _store;
  final OrbitMessagingApi _api;
  final _ed=Ed25519(),_dh=X25519(),_aead=AesGcm.with256bits();
  final _random=Random.secure();
  final Map<String,OrbitMessagingRemoteDevice> _verified={};

  @override
  bool get independentlyVerified=>false; // external protocol review pending
  @override
  String get protocol=>suite;

  Uint8List randomBytes(int n)=>Uint8List.fromList(
    List<int>.generate(n,(_)=>_random.nextInt(256)));
  Uint8List decode(String s,int n){
    final b=base64Decode(s);
    if(b.length!=n||base64Encode(b)!=s){
      throw const FormatException('Invalid messaging key encoding');
    }
    return Uint8List.fromList(b);
  }
  SimplePublicKey edPublic(String s)=>
    SimplePublicKey(decode(s,32),type:KeyPairType.ed25519);
  SimplePublicKey xPublic(String s)=>
    SimplePublicKey(decode(s,32),type:KeyPairType.x25519);
  SimpleKeyPairData privateEd(OrbitMessagingDeviceMaterial m)=>
    SimpleKeyPairData(decode(m.identityPrivate,32),
      publicKey:edPublic(m.identityPublic),type:KeyPairType.ed25519);
  SimpleKeyPairData privateX(OrbitMessagingDeviceMaterial m)=>
    SimpleKeyPairData(decode(m.prekeyPrivate,32),
      publicKey:xPublic(m.prekeyPublic),type:KeyPairType.x25519);

  Future<OrbitMessagingDeviceMaterial> material({bool create=false}) async {
    final active=await _source.current();
    final old=await _store.read(active.owner,active.device);
    if(old!=null)return old;
    if(!create)throw OrbitMessagingSecurityException(
      'This device has not initialized its messaging private keys.',403);
    final id=await _ed.newKeyPair();
    final idPub=await id.extractPublicKey();
    final pre=await _dh.newKeyPair();
    final prePub=await pre.extractPublicKey();
    final record=OrbitMessagingDeviceMaterial(
      owner:active.owner,device:active.device,prekeyId:1,
      identityPrivate:base64Encode(await id.extractPrivateKeyBytes()),
      identityPublic:base64Encode(idPub.bytes),
      prekeyPrivate:base64Encode(await pre.extractPrivateKeyBytes()),
      prekeyPublic:base64Encode(prePub.bytes));
    await _store.write(record);
    return record;
  }

  @override
  Future<OrbitMessagingPublicKeyBundle> setupDevice() async {
    final m=await material(create:true);
    final context=utf8.encode(signedContext+'|'+m.device+'|'+
      m.prekeyId.toString()+'|');
    final sign=await _ed.sign([...context,...decode(m.prekeyPublic,32)],
      keyPair:privateEd(m));
    return OrbitMessagingPublicKeyBundle(
      identityEd25519:m.identityPublic,
      signedPrekeyX25519:m.prekeyPublic,
      signature:base64Encode(sign.bytes),signedPrekeyId:m.prekeyId,
      oneTimePrekeys:const []);
  }

  @override
  Future<void> verifyPeerIdentity(OrbitMessagingKeyDirectory directory) async {
    final local=await _source.current();
    for(final d in directory.devices){
      final expected=hashes.sha256.convert(utf8.encode(d.identity)).toString();
      if(expected!=d.fingerprint)throw OrbitMessagingSecurityException(
        'Sender identity fingerprint mismatch.',409);
      final raw=utf8.encode(signedContext+'|'+d.id+'|'+
        d.signedPrekeyId.toString()+'|');
      if(!await _ed.verify([...raw,...decode(d.signedPrekey,32)],
        signature:Signature(decode(d.signature,64),
          publicKey:edPublic(d.identity)))){
        throw OrbitMessagingSecurityException(
          'Signed device prekey could not be authenticated.',409);
      }
      await _store.pinIdentity(local.owner,directory.userId,d.id,expected);
      _verified[directory.userId+'|'+d.id]=d;
    }
  }

  String info(String conversation,int epoch,String device)=>
    suite+'|'+conversation+'|'+epoch.toString()+'|'+device;

  Future<SecretKey> derive(SimpleKeyPair own,SimplePublicKey remote,
      List<int> salt,String infoString) async {
    final shared=await _dh.sharedSecretKey(
      keyPair:own,remotePublicKey:remote);
    return Hkdf(hmac:Hmac.sha256(),outputLength:32).deriveKey(
      secretKey:shared,nonce:salt,info:utf8.encode(infoString));
  }

  @override
  Future<OrbitEncryptedSend> encrypt({required String conversationId,
      required int groupEpoch,required String kind,
      required Uint8List plaintext,
      required Map<String,OrbitMessagingKeyDirectory> recipients}) async {
    if(conversationId.isEmpty||groupEpoch<1||
      plaintext.isEmpty||plaintext.length>22000){
      throw OrbitMessagingSecurityException(
        'Encrypted message exceeds the safe envelope size.',422);
    }
    final m=await material();
    final envelopes=<OrbitCipherEnvelope>[];
    final seen=<String>{};
    for(final directory in recipients.values){
      await verifyPeerIdentity(directory);
      for(final d in directory.devices){
        if(!seen.add(d.id))throw OrbitMessagingSecurityException(
          'Duplicate recipient device.',409);
        final ephemeral=await _dh.newKeyPair();
        final epk=await ephemeral.extractPublicKey();
        final salt=randomBytes(24),nonce=_aead.newNonce();
        final header=<String,Object>{
          'v':1,'protocol':suite,
          'sender_id':m.owner,'sender_device':m.device,
          'sender_identity':m.identityPublic,
          'recipient_device':d.id,'recipient_spk':d.signedPrekeyId,
          'recipient_key_version':d.keyVersion,
          'ephemeral':base64Encode(epk.bytes),
          'salt':base64Encode(salt),'nonce':base64Encode(nonce),
          'conversation_id':conversationId,'epoch':groupEpoch,'kind':kind,
        };
        final unsigned=utf8.encode(jsonEncode(header));
        final key=await derive(ephemeral,xPublic(d.signedPrekey),salt,
          info(conversationId,groupEpoch,d.id));
        final box=await _aead.encrypt(plaintext,
          secretKey:key,nonce:nonce,aad:unsigned);
        final body=[...box.cipherText,...box.mac.bytes];
        final signature=await _ed.sign(
          [...unsigned,...hashes.sha256.convert(body).bytes],
          keyPair:privateEd(m));
        final encodedHeader=utf8.encode(jsonEncode({
          ...header,'signature':base64Encode(signature.bytes),
        }));
        if(encodedHeader.length>4096){
          throw OrbitMessagingSecurityException('Header is too large.',422);
        }
        envelopes.add(OrbitCipherEnvelope(deviceId:d.id,
          ciphertextB64:base64Encode(body),
          headerB64:base64Encode(encodedHeader)));
      }
    }
    if(envelopes.isEmpty)throw OrbitMessagingSecurityException(
      'No eligible device encryption keys.',409);
    return OrbitEncryptedSend(protocol:suite,kind:kind,
      groupEpoch:groupEpoch,envelopes:envelopes);
  }

  @override
  Future<Uint8List> decrypt({required OrbitMailboxEnvelope envelope,
      required String conversationId}) async {
    final m=await material();
    final rawHeader=base64Decode(envelope.headerB64);
    if(rawHeader.length>4096)throw const FormatException('Invalid header size.');
    final json=jsonDecode(utf8.decode(rawHeader));
    if(json is! Map)throw const FormatException('Invalid header.');
    final header=Map<String,dynamic>.from(json);
    final rawSignature=header.remove('signature');
    if(rawSignature is! String||
       header['v']!=1||header['protocol']!=suite||
       header['sender_id']!=envelope.senderId||
       header['sender_device']!=envelope.senderDeviceId||
       header['recipient_device']!=m.device||
       header['recipient_spk']!=m.prekeyId||
       header['recipient_key_version']!=envelope.keyVersion||
       header['conversation_id']!=conversationId||
       header['epoch']!=envelope.groupEpoch||
       header['kind']!=envelope.kind||envelope.protocol!=suite){
      throw OrbitMessagingSecurityException(
        'Authenticated conversation scope mismatch.',409);
    }
    final directory=await _api.discoverKeys(envelope.senderId,
      consumeOneTimePrekey:false);
    await verifyPeerIdentity(directory);
    final remote=_verified[envelope.senderId+'|'+envelope.senderDeviceId];
    if(remote==null||remote.identity!=header['sender_identity']){
      throw OrbitMessagingSecurityException(
        'The sender device identity has changed.',409);
    }
    final raw=base64Decode(envelope.ciphertextB64);
    if(raw.length<17||raw.length>32768){
      throw const FormatException('Invalid ciphertext size.');
    }
    final unsigned=utf8.encode(jsonEncode(header));
    final signed=[...unsigned,...hashes.sha256.convert(raw).bytes];
    if(!await _ed.verify(signed,signature:Signature(
        decode(rawSignature,64),publicKey:edPublic(remote.identity)))){
      throw OrbitMessagingSecurityException('Invalid message signature.',409);
    }
    final salt=decode(header['salt'] as String,24);
    final nonce=decode(header['nonce'] as String,12);
    final key=await derive(privateX(m),
      xPublic(header['ephemeral'] as String),salt,
      info(conversationId,envelope.groupEpoch,m.device));
    try{
      final plaintext=await _aead.decrypt(SecretBox(
        raw.sublist(0,raw.length-16),nonce:nonce,
        mac:Mac(raw.sublist(raw.length-16))),
        secretKey:key,aad:unsigned);
      return Uint8List.fromList(plaintext);
    }on SecretBoxAuthenticationError{
      throw OrbitMessagingSecurityException(
        'Ciphertext authentication failed.',409);
    }
  }
  @override
  Future<void> purgeForOwner(String owner) async {
    _verified.clear();
    await _store.purge(owner);
  }
}

abstract class OrbitMessagingDeviceSource {
  Future<({String owner,String device})> current();
}
class OrbitLiveMessagingDeviceSource implements OrbitMessagingDeviceSource {
  @override
  Future<({String owner,String device})> current() async {
    final identity=OrbitIdentityClient.instance;
    final owner=await identity.currentLocalSocialOwner();
    if(owner==null)throw OrbitMessagingSecurityException(
      'Sign in before accessing messaging private keys.',401);
    final device=await identity.trustedMediaDevice();
    return (owner:owner,device:device.id);
  }
}

class OrbitMessagingDeviceMaterial {
  const OrbitMessagingDeviceMaterial({required this.owner,required this.device,
    required this.identityPrivate,required this.identityPublic,
    required this.prekeyPrivate,required this.prekeyPublic,required this.prekeyId});
  final String owner,device,identityPrivate,identityPublic;
  final String prekeyPrivate,prekeyPublic;
  final int prekeyId;
  Map<String,Object?> toJson()=>{'owner':owner,'device':device,
    'identity_private':identityPrivate,'identity_public':identityPublic,
    'prekey_private':prekeyPrivate,'prekey_public':prekeyPublic,
    'prekey_id':prekeyId};
  factory OrbitMessagingDeviceMaterial.fromJson(Map<String,dynamic> j)=>
    OrbitMessagingDeviceMaterial(owner:j['owner'] as String,
      device:j['device'] as String,
      identityPrivate:j['identity_private'] as String,
      identityPublic:j['identity_public'] as String,
      prekeyPrivate:j['prekey_private'] as String,
      prekeyPublic:j['prekey_public'] as String,
      prekeyId:(j['prekey_id'] as num).toInt());
}

abstract class OrbitMessagingDeviceStore {
  Future<OrbitMessagingDeviceMaterial?> read(String owner,String device);
  Future<void> write(OrbitMessagingDeviceMaterial record);
  Future<void> pinIdentity(String owner,String peer,String device,String fingerprint);
  Future<void> purge(String owner);
}
class OrbitPlatformMessagingDeviceStore implements OrbitMessagingDeviceStore {
  OrbitPlatformMessagingDeviceStore({FlutterSecureStorage? storage})
    : _storage=storage??const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String localKey(String owner,String device)=>
    'orbit.m13.material.v1.'+owner+'.'+device;
  String pinKey(String owner,String peer,String device)=>
    'orbit.m13.pin.v1.'+owner+'.'+peer+'.'+device;
  @override
  Future<OrbitMessagingDeviceMaterial?> read(String owner,String device) async {
    final raw=await _storage.read(key:localKey(owner,device));
    if(raw==null)return null;
    final m=OrbitMessagingDeviceMaterial.fromJson(
      Map<String,dynamic>.from(jsonDecode(raw) as Map));
    if(m.owner!=owner||m.device!=device){
      throw OrbitMessagingSecurityException('Device private-key owner mismatch.',409);
    }
    return m;
  }
  @override
  Future<void> write(OrbitMessagingDeviceMaterial m)=>
    _storage.write(key:localKey(m.owner,m.device),
      value:jsonEncode(m.toJson()));
  @override
  Future<void> pinIdentity(String owner,String peer,String device,String fingerprint) async {
    final key=pinKey(owner,peer,device);
    final old=await _storage.read(key:key);
    if(old!=null&&old!=fingerprint){
      throw OrbitMessagingSecurityException(
        'The contact identity changed. Verify it before proceeding.',409);
    }
    if(old==null)await _storage.write(key:key,value:fingerprint);
  }
  @override
  Future<void> purge(String owner) async {
    final records=await _storage.readAll();
    for(final key in records.keys){
      if(key.startsWith('orbit.m13.material.v1.'+owner+'.')||
         key.startsWith('orbit.m13.pin.v1.'+owner+'.')){
        await _storage.delete(key:key);
      }
    }
  }
}
