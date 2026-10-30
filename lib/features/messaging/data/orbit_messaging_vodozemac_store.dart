import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'orbit_messaging_models.dart';

/// One OS-protected, AES-256-GCM encrypted owner/device snapshot.
///
/// A single storage write commits all outbound Olm session pickles, group
/// sender-chain changes and ciphertext retry state before any packet leaves
/// the device. Every native pickle inside the snapshot is also encrypted with
/// its own random, OS-protected 256-bit pickle key. Never use M6 media keys.
class OrbitVodozemacStateStore {
  OrbitVodozemacStateStore({FlutterSecureStorage? storage}):
    _storage=storage??const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final AesGcm _aead=AesGcm.with256bits();

  String _recordId(String owner,String device)=>
    base64Url.encode(utf8.encode('$owner|$device')).replaceAll('=','');
  String _keyName(String owner,String device)=>
    'orbit.messaging.olm.pickle.v1.${_recordId(owner,device)}';
  String _stateName(String owner,String device)=>
    'orbit.messaging.olm.snapshot.v1.${_recordId(owner,device)}';
  List<int> _aad(String owner,String device)=>
    utf8.encode('orbit-m13-vodozemac-state-v1|$owner|$device');

  Future<String> pickleKey(String owner,String device) async {
    if(owner.isEmpty||device.isEmpty)throw OrbitMessagingSecurityException(
      'Trusted device and account required for private ratchets.',401);
    final name=_keyName(owner,device);
    var stored=await _storage.read(key:name);
    if(stored==null){
      final secret=await _aead.newSecretKey();
      stored=base64Encode(await secret.extractBytes());
      await _storage.write(key:name,value:stored);
    }
    if(base64Decode(stored).length!=32){
      throw OrbitMessagingSecurityException(
        'Native ratchet storage key is unavailable.',403);
    }
    return stored;
  }

  Map<String,dynamic> _empty()=> <String,dynamic>{
    'v':1,'account':null,'public':null,'published':false,
    'next_prekey_id':25,
    'sessions_out':<String,dynamic>{},
    'sessions_in':<String,dynamic>{},
    'groups_out':<String,dynamic>{},
    'groups_in':<String,dynamic>{},
    'group_pending':<String,dynamic>{},
    'processed_sender_keys':<String,dynamic>{},
    'identity_pins':<String,dynamic>{},
    'decryption_pending':<String,dynamic>{},
  };

  Future<Map<String,dynamic>> read(String owner,String device) async {
    final name=_stateName(owner,device);
    final raw=await _storage.read(key:name);
    if(raw==null)return _empty();
    try{
      final key=SecretKey(base64Decode(await pickleKey(owner,device)));
      final item=Map<String,dynamic>.from(jsonDecode(raw) as Map);
      final box=SecretBox(
        base64Decode(item['ciphertext'] as String),
        nonce:base64Decode(item['nonce'] as String),
        mac:Mac(base64Decode(item['tag'] as String)),
      );
      final clear=await _aead.decrypt(
        box,secretKey:key,aad:_aad(owner,device));
      final parsed=Map<String,dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
      if(parsed['v']!=1)throw const FormatException('Unsupported protocol state.');
      for(final k in ['sessions_out','sessions_in','groups_out','groups_in',
          'group_pending','identity_pins','decryption_pending',
          'processed_sender_keys']){
        if(parsed[k] is! Map)throw const FormatException('Missing ratchet state.');
      }
      return parsed;
    }catch(_){
      // Never replace an unreadable snapshot with new identities or sessions.
      throw OrbitMessagingSecurityException(
        'Private ratchet state could not be authenticated. '
        'Do not reset keys automatically.',409);
    }
  }

  Future<void> write(String owner,String device,
      Map<String,dynamic> value) async {
    if(value['v']!=1)throw OrbitMessagingSecurityException(
      'Invalid protocol state version.',409);
    final key=SecretKey(base64Decode(await pickleKey(owner,device)));
    final nonce=_aead.newNonce();
    final sealed=await _aead.encrypt(utf8.encode(jsonEncode(value)),
      secretKey:key,nonce:nonce,aad:_aad(owner,device));
    await _storage.write(key:_stateName(owner,device),value:jsonEncode({
      'nonce':base64Encode(sealed.nonce),
      'ciphertext':base64Encode(sealed.cipherText),
      'tag':base64Encode(sealed.mac.bytes),
    }));
  }

  Future<void> purgeOwner(String owner) async {
    if(owner.isEmpty)return;
    final records=await _storage.readAll();
    for(final key in records.keys){
      if(!key.startsWith('orbit.messaging.olm.'))continue;
      final suffix=key.substring(key.lastIndexOf('.')+1);
      try{
        final normalized=base64Url.normalize(suffix);
        final decoded=utf8.decode(base64Url.decode(normalized));
        if(decoded.startsWith('$owner|')){
          await _storage.delete(key:key);
        }
      }catch(_){
        // A malformed key must never trigger deletion of another owner.
      }
    }
  }
}
