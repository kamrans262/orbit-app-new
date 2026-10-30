import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'orbit_messaging_api.dart';
import 'orbit_messaging_cipher.dart';
import 'orbit_messaging_models.dart';
import 'orbit_messaging_sealed_box_cipher.dart' show OrbitMessagingDeviceSource,
  OrbitLiveMessagingDeviceSource;
import 'orbit_messaging_vodozemac_ffi.dart';
import 'orbit_messaging_vodozemac_store.dart';

class _NativeState {
  _NativeState(this.owner,this.device,this.key,this.data);
  final String owner,device,key;
  final Map<String,dynamic> data;
  Map<String,dynamic> bucket(String name) =>
    Map<String,dynamic>.from(data[name] as Map);
  void put(String name,Map<String,dynamic> values)=>data[name]=values;
}

/// Release candidate backed by the independently-audited Rust vodozemac
/// Olm Double Ratchet and Megolm sender ratchet. No bespoke DH/KDF/cipher.
/// The FFI wrapper, wire framing, secure-storage durability, membership
/// binding and distribution lifecycle REQUIRE an independent integration
/// review and multi-device acceptance before production use.
///
/// Never set independentlyVerified to true by a runtime toggle. A reviewed
/// application release must change this source after review evidence exists.
class OrbitMessagingVodozemacCipher implements OrbitMessagingCipher {
  OrbitMessagingVodozemacCipher({
    required OrbitVodozemacNative native,
    OrbitVodozemacStateStore? store,
    OrbitMessagingApi? api,
    OrbitMessagingDeviceSource? source,
  }):_native=native,
     _store=store??OrbitVodozemacStateStore(),
     _api=api??OrbitMessagingApi(),
     _source=source??OrbitLiveMessagingDeviceSource();

  final OrbitVodozemacNative _native;
  final OrbitVodozemacStateStore _store;
  final OrbitMessagingApi _api;
  final OrbitMessagingDeviceSource _source;
  final Ed25519 _ed25519=Ed25519();
  static const String protocolName='orbit-m13-olm-megolm-v1';
  final Map<String,DateTime> _lastPrekeyCheck=<String,DateTime>{};
  // Change ONLY in a source-reviewed release after native binary, licensing,
  // cross-device ratchet and media/session tests have all passed.
  static const bool releaseCertified=false;

  @override
  bool get independentlyVerified=>releaseCertified;
  @override
  String get protocol=>protocolName;

  Future<_NativeState> _open() async {
    final identity=await _source.current();
    final key=await _store.pickleKey(identity.owner,identity.device);
    final state=await _store.read(identity.owner,identity.device);
    return _NativeState(identity.owner,identity.device,key,state);
  }
  Future<void> _save(_NativeState s) =>
      _store.write(s.owner,s.device,s.data);

  Future<void> _ensureAccount(_NativeState s) async {
    if(s.data['account']!=null)return;
    final generated=_native.invoke({
      'op':'account_create','pickle_key_b64':s.key,'device_id':s.device,
    });
    s.data['account']=generated['account_pickle'];
    s.data['public']=<String,dynamic>{
      'identity_ed25519':generated['identity_ed25519'],
      'signed_prekey_x25519':generated['signed_prekey_x25519'],
      'signed_prekey_signature':generated['signed_prekey_signature'],
      'signed_prekey_id':generated['signed_prekey_id'],
      'one_time_prekeys':generated['one_time_prekeys'],
    };
    s.data['published']=false;
    await _save(s);
  }

  /// Replenish without rotating Ed25519/Curve25519 identity. A crash after
  /// preparing the new prekeys retries the SAME signed public key batch;
  /// a confirmed registration clears it. The server controls how many
  /// unclaimed keys remain and validates every key ID.
  Future<void> _replenishIfNeeded(_NativeState s) async {
    if(s.data['published']!=true)return;
    final public=Map<String,dynamic>.from(s.data['public'] as Map);
    if((public['one_time_prekeys'] as List).isNotEmpty)return;
    final id='${s.owner}|${s.device}';
    final now=DateTime.now();
    final previous=_lastPrekeyCheck[id];
    if(previous!=null &&
        now.difference(previous)<const Duration(minutes:10))return;
    final directory=await _api.myDevices();
    final rows=directory['devices'];
    if(rows is! List)throw OrbitMessagingSecurityException(
      'Trusted device prekey directory is not available.',409);
    final local=rows.whereType<Map>().map(
      (v)=>Map<String,dynamic>.from(v)).where(
      (v)=>v['id']==s.device).toList();
    if(local.length!=1||local.single['trusted']!=true ||
        local.single['messaging_keys_registered']!=true) {
      throw OrbitMessagingSecurityException(
        'Trusted messaging device registration is missing.',409);
    }
    final remaining=local.single['available_one_time_prekeys'];
    if(remaining is! num)throw OrbitMessagingSecurityException(
      'Device prekey inventory was not returned.',409);
    _lastPrekeyCheck[id]=now;
    if(remaining>=8)return;
    final nextId=(s.data['next_prekey_id'] as num?)?.toInt()??25;
    final updated=_native.invoke({
      'op':'account_replenish_prekeys',
      'pickle_key_b64':s.key,'account_pickle':s.data['account'],
      'start_id':nextId,'count':24,
    });
    s.data['account']=updated['account_pickle'];
    s.data['next_prekey_id']=updated['next_key_id'];
    public['one_time_prekeys']=updated['one_time_prekeys'];
    s.data['public']=public;
    s.data['published']=false;
    // Account pickle and new public batch must survive a failed request.
    await _save(s);
  }

  @override
  Future<OrbitMessagingPublicKeyBundle> setupDevice() async {
    final s=await _open();
    await _ensureAccount(s);
    await _replenishIfNeeded(s);
    final p=Map<String,dynamic>.from(s.data['public'] as Map);
    final raw=p['one_time_prekeys'] as List;
    return OrbitMessagingPublicKeyBundle(
      identityEd25519:p['identity_ed25519'] as String,
      signedPrekeyX25519:p['signed_prekey_x25519'] as String,
      signature:p['signed_prekey_signature'] as String,
      signedPrekeyId:(p['signed_prekey_id'] as num).toInt(),
      oneTimePrekeys:s.data['published']==true
        ?const <OrbitPublicOneTimePrekey>[]
        :raw.map((v){
          final m=Map<String,dynamic>.from(v as Map);
          return OrbitPublicOneTimePrekey(
            (m['key_id'] as num).toInt(),m['public_x25519'] as String);
        }).toList(growable:false),
    );
  }

  @override
  Future<void> confirmDeviceRegistration() async {
    final s=await _open();
    if(s.data['account']==null)return;
    s.data['published']=true;
    // Avoid republishing a claimed one-time prekey on future app startups.
    final p=Map<String,dynamic>.from(s.data['public'] as Map);
    p['one_time_prekeys']=<Object>[];
    s.data['public']=p;
    await _save(s);
  }

  Future<void> _pin(_NativeState s,String user,
      OrbitMessagingRemoteDevice remote) async {
    final expected=hashes.sha256.convert(
      utf8.encode(remote.identity)).toString();
    if(expected!=remote.fingerprint)throw OrbitMessagingSecurityException(
      'Messaging identity fingerprint does not match the directory.',409);
    final ed=base64Decode(remote.identity);
    final curve=base64Decode(remote.signedPrekey);
    final sig=base64Decode(remote.signature);
    if(ed.length!=32||curve.length!=32||sig.length!=64){
      throw OrbitMessagingSecurityException(
        'Recipient key or signature is malformed.',409);
    }
    final signed=utf8.encode('orbit-m13-signed-prekey-v1|'+remote.id+'|'+
      remote.signedPrekeyId.toString()+'|');
    final okay=await _ed25519.verify([...signed,...curve],signature:Signature(
      sig,publicKey:SimplePublicKey(ed,type:KeyPairType.ed25519)));
    if(!okay)throw OrbitMessagingSecurityException(
      'Signed device identity could not be authenticated.',409);
    final pins=s.bucket('identity_pins');
    final id='$user|${remote.id}';
    final existing=pins[id];
    if(existing!=null && existing!=expected){
      throw OrbitMessagingSecurityException(
        'Contact identity changed. Verify the safety number before sending.',409);
    }
    pins[id]=expected;
    s.put('identity_pins',pins);
  }

  @override
  Future<void> verifyPeerIdentity(OrbitMessagingKeyDirectory peer) async {
    final s=await _open();
    await _ensureAccount(s);
    for(final device in peer.devices)await _pin(s,peer.userId,device);
    await _save(s);
  }

  /// Explicit recovery only after the user independently verifies this
  /// FULL safety fingerprint with the contact. Never auto-accept a new key.
  /// Existing Olm sessions and Circle sender-key packets involving that
  /// device are discarded so later messages require fresh authenticated keys.
  Future<void> acceptVerifiedPeerIdentity({
    required String peerId,required String deviceId,
    required String verifiedFingerprint,
  }) async {
    if(peerId.isEmpty||deviceId.isEmpty||
       !RegExp(r'^[a-f0-9]{64}
      _NativeState s,String recipient,OrbitMessagingRemoteDevice remote,
      String conversation,int epoch,String kind,Map<String,dynamic> payload,
      ) async {
    await _pin(s,recipient,remote);
    final out=s.bucket('sessions_out');
    var record=out[remote.id] is Map
      ?Map<String,dynamic>.from(out[remote.id] as Map):null;
    if(record!=null){
      if(record['fingerprint']!=remote.fingerprint ||
          record['key_version']!=remote.keyVersion ||
          record['curve']!=remote.signedPrekey){
        throw OrbitMessagingSecurityException(
          'A trusted recipient device changed keys. Review before sending.',409);
      }
    }else{
      // Claim an X3DH one-time key ONLY when a new Olm session is required.
      final fresh=await _api.discoverKeys(recipient,
        consumeOneTimePrekey:true);
      final matching=fresh.devices.where((d)=>d.id==remote.id).toList();
      if(matching.length!=1||matching.single.oneTimePublic==null){
        throw OrbitMessagingSecurityException(
          'Recipient has no available one-time messaging prekey.',409);
      }
      final claimed=matching.single;
      await _pin(s,recipient,claimed);
      final initial=_native.invoke({
        'op':'session_outbound','pickle_key_b64':s.key,
        'account_pickle':s.data['account'],
        'recipient_curve_b64':claimed.signedPrekey,
        'recipient_one_time_b64':claimed.oneTimePublic,
      });
      record={
        'pickle':initial['session_pickle'],
        'sid':initial['session_id'],'curve':claimed.signedPrekey,
        'fingerprint':claimed.fingerprint,
        'key_version':claimed.keyVersion,
      };
    }
    final encrypted=_native.invoke({
      'op':'session_encrypt','pickle_key_b64':s.key,
      'session_pickle':record['pickle'],
      'plaintext_b64':base64Encode(utf8.encode(jsonEncode(payload))),
    });
    record['pickle']=encrypted['session_pickle'];
    out[remote.id]=record;
    s.put('sessions_out',out);
    final public=Map<String,dynamic>.from(s.data['public'] as Map);
    final header={
      'v':1,'type':'olm','protocol':protocol,
      'cid':conversation,'epoch':epoch,'kind':kind,
      'sender':s.owner,'sender_device':s.device,
      'sender_identity':public['identity_ed25519'],
      'sender_curve':public['signed_prekey_x25519'],
      'recipient_device':remote.id,
      'message_type':encrypted['message_type'],
      'session_id':encrypted['session_id'],
    };
    return OrbitCipherEnvelope(
      deviceId:remote.id,
      ciphertextB64:encrypted['ciphertext_b64'] as String,
      headerB64:base64Encode(utf8.encode(jsonEncode(header))));
  }

  Future<List<OrbitCipherEnvelope>> _sealAll(
      _NativeState s,Map<String,OrbitMessagingKeyDirectory> recipients,
      String conversation,int epoch,String kind,
      Map<String,dynamic> payload) async {
    final envelopes=<OrbitCipherEnvelope>[];
    final ids=<String>{};
    for(final directory in recipients.values){
      for(final remote in directory.devices){
        if(!ids.add(remote.id)){
          throw OrbitMessagingSecurityException(
            'Duplicate recipient device in authenticated roster.',409);
        }
        envelopes.add(await _sealOne(s,directory.userId,remote,
          conversation,epoch,kind,payload));
      }
    }
    if(envelopes.isEmpty)throw OrbitMessagingSecurityException(
      'No approved recipient devices.',409);
    return envelopes;
  }

  Map<String,dynamic> _header(String raw) {
    final decoded=jsonDecode(utf8.decode(base64Decode(raw)));
    if(decoded is! Map)throw OrbitMessagingSecurityException(
      'Encrypted ratchet header is invalid.',409);
    return Map<String,dynamic>.from(decoded);
  }

  Future<Map<String,dynamic>> _openOlm(
      _NativeState s,OrbitMailboxEnvelope envelope,
      String conversation,{bool remember=false}) async {
    final header=_header(envelope.headerB64);
    if(header['v']!=1||header['type']!='olm'||
        header['protocol']!=protocol||
        envelope.protocol!=protocol||
        header['cid']!=conversation||
        header['epoch']!=envelope.groupEpoch||
        header['sender']!=envelope.senderId||
        header['sender_device']!=envelope.senderDeviceId||
        header['recipient_device']!=s.device||
        header['kind']!=envelope.kind) {
      throw OrbitMessagingSecurityException(
        'Encrypted message scope or recipient device changed.',409);
    }
    final directory=await _api.discoverKeys(envelope.senderId,
      consumeOneTimePrekey:false);
    final candidates=directory.devices.where(
      (d)=>d.id==envelope.senderDeviceId).toList();
    if(candidates.length!=1)throw OrbitMessagingSecurityException(
      'Authenticated sender device is no longer trusted.',409);
    final remote=candidates.single;
    await _pin(s,directory.userId,remote);
    if(header['sender_identity']!=remote.identity ||
        header['sender_curve']!=remote.signedPrekey){
      throw OrbitMessagingSecurityException(
        'Authenticated sender identity did not match directory.',409);
    }
    final sid=header['session_id'];
    final msgType=header['message_type'];
    if(sid is! String || msgType is! int || (msgType!=0&&msgType!=1)){
      throw OrbitMessagingSecurityException(
        'Malformed Olm session header.',409);
    }
    final inKey='${remote.id}|$sid';
    final inbound=s.bucket('sessions_in');
    final outbound=s.bucket('sessions_out');
    final known=inbound[inKey] is Map
      ?Map<String,dynamic>.from(inbound[inKey] as Map):null;
    final out=outbound[remote.id] is Map
      ?Map<String,dynamic>.from(outbound[remote.id] as Map):null;
    // A sender receives its own other-device/same-device mailbox copy.
    // Its outbound chain cannot decrypt a copy sent to itself; establish
    // the matching inbound prekey chain instead.
    final isOutbound=known==null && out!=null && out['sid']==sid &&
      remote.id!=s.device;
    final record=known??(isOutbound?out:null);
    late Map<String,dynamic> decrypted;
    if(record!=null){
      decrypted=_native.invoke({
        'op':'session_decrypt','pickle_key_b64':s.key,
        'session_pickle':record['pickle'],
        'message_type':msgType,
        'ciphertext_b64':envelope.ciphertextB64,
      });
      record['pickle']=decrypted['session_pickle'];
      if(isOutbound)outbound[remote.id]=record;
      else inbound[inKey]=record;
    }else{
      if(msgType!=0)throw OrbitMessagingSecurityException(
        'No authenticated Olm prekey session exists.',409);
      decrypted=_native.invoke({
        'op':'session_inbound','pickle_key_b64':s.key,
        'account_pickle':s.data['account'],
        'sender_curve_b64':remote.signedPrekey,
        'message_type':msgType,
        'ciphertext_b64':envelope.ciphertextB64,
      });
      s.data['account']=decrypted['account_pickle'];
      inbound[inKey]={
        'pickle':decrypted['session_pickle'],'sid':sid,
        'curve':remote.signedPrekey,
        'fingerprint':remote.fingerprint,
        'key_version':remote.keyVersion,
      };
    }
    s.put('sessions_in',inbound);
    s.put('sessions_out',outbound);
    final plaintext=jsonDecode(utf8.decode(
      base64Decode(decrypted['plaintext_b64'] as String)));
    if(plaintext is! Map)throw OrbitMessagingSecurityException(
      'Authenticated Olm payload is invalid.',409);
    final data=Map<String,dynamic>.from(plaintext);
    if(data['cid']!=conversation||data['epoch']!=envelope.groupEpoch||
        data['kind']!=envelope.kind||data['sender']!=envelope.senderId||
        data['sender_device']!=envelope.senderDeviceId){
      throw OrbitMessagingSecurityException(
        'Authenticated Olm payload is outside its conversation.',409);
    }
    if(remember){
      final p=s.bucket('decryption_pending');
      p[envelope.id]={
        'conversation':conversation,
        'message_id':envelope.messageId,
        'plaintext_b64':data['body_b64'],
      };
      if(p.length>160)throw OrbitMessagingSecurityException(
        'Too many uncommitted encrypted message decryptions.',503);
      s.put('decryption_pending',p);
    }
    return data;
  }

  @override
  Future<void> prepareGroupEpoch({
    required String conversationId,
    required int groupEpoch,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  }) async {
    final s=await _open();
    await _ensureAccount(s);
    final roster=<String>[];
    for(final directory in recipients.values){
      for(final d in directory.devices){
        await _pin(s,directory.userId,d);
        roster.add('${directory.userId}|${d.id}|${d.fingerprint}|'+
          d.keyVersion.toString());
      }
    }
    roster.sort();
    final fingerprint=hashes.sha256.convert(
      utf8.encode(roster.join('\n'))).toString();
    final groups=s.bucket('groups_out');
    final ready=groups[conversationId] is Map
      ?Map<String,dynamic>.from(groups[conversationId] as Map):null;
    if(ready!=null && ready['epoch']==groupEpoch &&
        ready['roster']==fingerprint &&
        !s.bucket('group_pending').containsKey(conversationId)){
      return;
    }

    final pending=s.bucket('group_pending');
    Map<String,dynamic> packet;
    final existing=pending[conversationId] is Map
      ?Map<String,dynamic>.from(pending[conversationId] as Map):null;
    if(existing!=null && existing['epoch']==groupEpoch &&
        existing['roster']==fingerprint){
      packet=existing;
    }else{
      // Every membership, consent or trusted-device change creates a
      // completely new Megolm sender ratchet and fresh Olm key envelopes.
      final group=_native.invoke({
        'op':'group_create','pickle_key_b64':s.key,
      });
      // This sending device owns the new Megolm session. Provision a local
      // authenticated inbound copy so its own delivered envelope can also
      // be decrypted. Other devices still require Olm-wrapped distribution.
      final selfKey='${s.device}|${group['session_id']}';
      final imported=_native.invoke({
        'op':'group_import','pickle_key_b64':s.key,
        'session_key':group['session_key'],
      });
      final inbox=s.bucket('groups_in');
      inbox[selfKey]={
        'conversation':conversationId,'epoch':groupEpoch,
        'pickle':imported['inbound_pickle'],
      };
      s.put('groups_in',inbox);
      final wrappedPayload={
        't':'sender_key','cid':conversationId,'epoch':groupEpoch,
        'kind':'sender_key','sender':s.owner,'sender_device':s.device,
        'session_id':group['session_id'],
        'session_key':group['session_key'],
      };
      final encrypted=await _sealAll(s,recipients,conversationId,
        groupEpoch,'sender_key',wrappedPayload);
      final clientId=const Uuid().v4();
      packet={
        'client_id':clientId,'epoch':groupEpoch,'roster':fingerprint,
        'group_pickle':group['group_pickle'],
        'session_id':group['session_id'],
        'session_key':group['session_key'],
        'envelopes':encrypted.map((e)=>e.toJson()).toList(),
      };
      pending[conversationId]=packet;
      s.put('group_pending',pending);
      // Ratchet advances and pending immutable ciphertext are one protected
      // owner/device snapshot; a timeout retries the same client ID.
      await _save(s);
    }
    final raw=packet['envelopes'] as List;
    final result=await _api.distributeCircleSenderKey(conversationId,
      clientId:packet['client_id'] as String,groupEpoch:groupEpoch,
      protocol:protocol,
      envelopes:raw.map((e){
        final value=Map<String,dynamic>.from(e as Map);
        return OrbitCipherEnvelope(
          deviceId:value['device_id'] as String,
          ciphertextB64:value['ciphertext_b64'] as String,
          headerB64:value['protocol_header_b64'] as String);
      }).toList(growable:false));
    if(!result.stored||result.groupEpoch!=groupEpoch){
      throw OrbitMessagingSecurityException(
        'Circle sender-key rotation was not acknowledged.',503);
    }
    groups[conversationId]={
      'epoch':groupEpoch,'roster':fingerprint,
      'group_pickle':packet['group_pickle'],
      'session_id':packet['session_id'],
      'session_key':packet['session_key'],
    };
    pending.remove(conversationId);
    s.put('groups_out',groups);s.put('group_pending',pending);
    await _save(s);
  }

  @override
  Future<OrbitEncryptedSend> encrypt({
    required String conversationId,required int groupEpoch,
    required String kind,required Uint8List plaintext,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  }) async {
    final s=await _open();
    await _ensureAccount(s);
    if(plaintext.isEmpty||plaintext.length>22000){
      throw OrbitMessagingSecurityException(
        'Encrypted message exceeds the maximum plaintext size.',422);
    }
    final groups=s.bucket('groups_out');
    final group=groups[conversationId] is Map
      ?Map<String,dynamic>.from(groups[conversationId] as Map):null;
    final payload={
      't':group==null?'direct':'group','cid':conversationId,
      'epoch':groupEpoch,'kind':kind,'sender':s.owner,
      'sender_device':s.device,'body_b64':base64Encode(plaintext),
    };
    if(group==null){
      final envelopes=await _sealAll(s,recipients,conversationId,
        groupEpoch,kind,payload);
      await _save(s); // atomic state advance BEFORE ciphertext leaves
      return OrbitEncryptedSend(protocol:protocol,kind:kind,
        groupEpoch:groupEpoch,envelopes:envelopes);
    }
    if(group['epoch']!=groupEpoch ||
        s.bucket('group_pending').containsKey(conversationId)){
      throw OrbitMessagingSecurityException(
        'Circle sender keys must rotate before sending.',409);
    }
    final encrypted=_native.invoke({
      'op':'group_encrypt','pickle_key_b64':s.key,
      'group_pickle':group['group_pickle'],
      'plaintext_b64':base64Encode(utf8.encode(jsonEncode(payload))),
    });
    group['group_pickle']=encrypted['group_pickle'];
    groups[conversationId]=group;s.put('groups_out',groups);
    await _save(s);
    final header=base64Encode(utf8.encode(jsonEncode({
      'v':1,'type':'megolm','protocol':protocol,
      'cid':conversationId,'epoch':groupEpoch,'kind':kind,
      'sender':s.owner,'sender_device':s.device,
      'session_id':group['session_id'],
    })));
    final devices=<String>{};
    final packets=<OrbitCipherEnvelope>[];
    for(final directory in recipients.values){
      for(final d in directory.devices){
        if(!devices.add(d.id))throw OrbitMessagingSecurityException(
          'Duplicate authenticated group recipient device.',409);
        packets.add(OrbitCipherEnvelope(
          deviceId:d.id,headerB64:header,
          ciphertextB64:base64Encode(utf8.encode(
            encrypted['message_b64'] as String))));
      }
    }
    return OrbitEncryptedSend(protocol:protocol,kind:kind,
      groupEpoch:groupEpoch,envelopes:packets);
  }

  @override
  Future<void> refreshGroupKeys(
      String conversationId,int groupEpoch) async {
    final s=await _open();
    await _ensureAccount(s);
    String? cursor;
    for(var pageNumber=0;pageNumber<5;pageNumber++){
      final page=await _api.circleSenderKeys(conversationId,
        cursor:cursor,limit:100);
      if(page.groupEpoch!=groupEpoch)throw OrbitMessagingSecurityException(
        'Circle key directory epoch changed.',409);
      for(final distribution in page.items.reversed){
        if(distribution.groupEpoch!=groupEpoch ||
           distribution.protocol!=protocol)continue;
        final processed=s.bucket('processed_sender_keys');
        if(processed.containsKey(distribution.id))continue;
        if(distribution.senderDeviceId==s.device){
          // Sender's own inbound Megolm copy was committed when the
          // outbound chain was created; fail if its session was lost.
          final group=s.bucket('groups_out')[conversationId];
          if(group is! Map || group['epoch']!=groupEpoch ||
              !s.bucket('groups_in').containsKey(
                '${s.device}|${group['session_id']}')){
            throw OrbitMessagingSecurityException(
              'Local authenticated Circle sender-key state is missing.',409);
          }
          processed[distribution.id]=groupEpoch;
          s.put('processed_sender_keys',processed);
          await _save(s);
          continue;
        }
        final env=OrbitMailboxEnvelope(
          id:distribution.id,messageId:distribution.id,
          senderId:distribution.senderId,
          senderDeviceId:distribution.senderDeviceId,
          kind:'sender_key',protocol:distribution.protocol,
          groupEpoch:distribution.groupEpoch,
          keyVersion:distribution.recipientKeyVersion,
          ciphertextB64:distribution.ciphertextB64,
          headerB64:distribution.headerB64,
          createdAt:DateTime.now().toUtc());
        final opened=await _openOlm(s,env,conversationId);
        if(opened['t']!='sender_key' ||
            opened['session_key'] is! String ||
            opened['session_id'] is! String){
          throw OrbitMessagingSecurityException(
            'Untrusted Circle sender-key distribution.',409);
        }
        final id='${distribution.senderDeviceId}|${opened['session_id']}';
        final received=s.bucket('groups_in');
        if(!received.containsKey(id)){
          final imported=_native.invoke({
            'op':'group_import','pickle_key_b64':s.key,
            'session_key':opened['session_key'],
          });
          received[id]={
            'conversation':conversationId,'epoch':groupEpoch,
            'pickle':imported['inbound_pickle'],
          };
          s.put('groups_in',received);
        }
        final processed=s.bucket('processed_sender_keys');
        processed[distribution.id]=groupEpoch;
        if(processed.length>1000){
          throw OrbitMessagingSecurityException(
            'Circle key history requires safe archival before continuing.',503);
        }
        s.put('processed_sender_keys',processed);
        await _save(s);
      }
      cursor=page.nextCursor;
      if(cursor==null)break;
    }
  }

  @override
  Future<Uint8List> decrypt({
    required OrbitMailboxEnvelope envelope,
    required String conversationId,
  }) async {
    final s=await _open();
    await _ensureAccount(s);
    final pending=s.bucket('decryption_pending');
    final cached=pending[envelope.id] is Map
      ?Map<String,dynamic>.from(pending[envelope.id] as Map):null;
    if(cached!=null){
      if(cached['conversation']!=conversationId ||
          cached['message_id']!=envelope.messageId){
        throw OrbitMessagingSecurityException(
          'Replayed envelope does not match the authenticated recipient.',409);
      }
      return Uint8List.fromList(
        base64Decode(cached['plaintext_b64'] as String));
    }
    final header=_header(envelope.headerB64);
    if(header['type']=='olm'){
      final payload=await _openOlm(s,envelope,conversationId,remember:true);
      if(payload['t']!='direct'||payload['body_b64'] is! String){
        throw OrbitMessagingSecurityException(
          'Invalid Olm user-message content type.',409);
      }
      await _save(s);
      return Uint8List.fromList(base64Decode(payload['body_b64'] as String));
    }
    if(header['type']!='megolm'||header['protocol']!=protocol ||
        header['cid']!=conversationId||
        header['epoch']!=envelope.groupEpoch||
        header['sender']!=envelope.senderId||
        header['sender_device']!=envelope.senderDeviceId||
        header['kind']!=envelope.kind){
      throw OrbitMessagingSecurityException(
        'Authenticated Circle message scope changed.',409);
    }
    final id='${envelope.senderDeviceId}|${header['session_id']}';
    final groups=s.bucket('groups_in');
    final stored=groups[id] is Map
      ?Map<String,dynamic>.from(groups[id] as Map):null;
    if(stored==null||stored['conversation']!=conversationId ||
        stored['epoch']!=envelope.groupEpoch){
      throw OrbitMessagingSecurityException(
        'Authenticated Circle sender-key packet has not been received.',409);
    }
    final result=_native.invoke({
      'op':'group_decrypt','pickle_key_b64':s.key,
      'inbound_pickle':stored['pickle'],
      'message_b64':utf8.decode(base64Decode(envelope.ciphertextB64)),
    });
    final payload=jsonDecode(utf8.decode(
      base64Decode(result['plaintext_b64'] as String)));
    if(payload is! Map ||
        payload['t']!='group' ||
        payload['cid']!=conversationId||
        payload['epoch']!=envelope.groupEpoch||
        payload['kind']!=envelope.kind||
        payload['sender']!=envelope.senderId||
        payload['sender_device']!=envelope.senderDeviceId||
        payload['body_b64'] is! String){
      throw OrbitMessagingSecurityException(
        'Decrypted Circle content is not bound to current participants.',409);
    }
    stored['pickle']=result['inbound_pickle'];
    groups[id]=stored;s.put('groups_in',groups);
    pending[envelope.id]={
      'conversation':conversationId,'message_id':envelope.messageId,
      'plaintext_b64':payload['body_b64'],
    };
    if(pending.length>160)throw OrbitMessagingSecurityException(
      'Too many uncommitted decrypted messages.',503);
    s.put('decryption_pending',pending);
    await _save(s);
    return Uint8List.fromList(base64Decode(payload['body_b64'] as String));
  }

  @override
  Future<void> confirmStoredDecryption(String envelopeId) async {
    final s=await _open();
    final pending=s.bucket('decryption_pending');
    if(pending.remove(envelopeId)!=null){
      s.put('decryption_pending',pending);
      await _save(s);
    }
  }

  @override
  Future<void> purgeForOwner(String owner) async {
    _lastPrekeyCheck.removeWhere((key,_)=>key.startsWith('$owner|'));
    await _store.purgeOwner(owner);
  }
}
).hasMatch(verifiedFingerprint)){
      throw OrbitMessagingSecurityException(
        'The complete verified safety fingerprint is required.',422);
    }
    final directory=await _api.discoverKeys(peerId,
      consumeOneTimePrekey:false);
    final candidates=directory.devices.where((d)=>d.id==deviceId).toList();
    if(candidates.length!=1){
      throw OrbitMessagingSecurityException(
        'The device is no longer eligible for encrypted messages.',409);
    }
    final remote=candidates.single;
    final actual=hashes.sha256.convert(
      utf8.encode(remote.identity)).toString();
    if(verifiedFingerprint!=actual||
       actual!=remote.fingerprint){
      throw OrbitMessagingSecurityException(
        'Safety fingerprint mismatch. Do not accept this identity.',409);
    }
    // Verify the cryptographic Ed25519 signed Curve key before allowing
    // the explicit fingerprint replacement, including for a new device.
    final ed=base64Decode(remote.identity);
    final curve=base64Decode(remote.signedPrekey);
    final sig=base64Decode(remote.signature);
    if(ed.length!=32||curve.length!=32||sig.length!=64){
      throw OrbitMessagingSecurityException(
        'The replacement identity key is malformed.',409);
    }
    final signed=utf8.encode('orbit-m13-signed-prekey-v1|'+remote.id+'|'+
      remote.signedPrekeyId.toString()+'|');
    if(!await _ed25519.verify([...signed,...curve],signature:Signature(
      sig,publicKey:SimplePublicKey(ed,type:KeyPairType.ed25519)))){
      throw OrbitMessagingSecurityException(
        'Replacement device key signature is invalid.',409);
    }
    final s=await _open();
    final pins=s.bucket('identity_pins');
    final id='$peerId|$deviceId';
    if(pins[id]==actual)return;
    pins[id]=actual;
    s.put('identity_pins',pins);
    final outgoing=s.bucket('sessions_out')..remove(deviceId);
    final incoming=s.bucket('sessions_in')
      ..removeWhere((id,_)=>id.startsWith('$deviceId|'));
    final groups=s.bucket('groups_in')
      ..removeWhere((id,_)=>id.startsWith('$deviceId|'));
    // Fresh Circle epochs are rechecked by Laravel before distribution.
    // Invalidate outbound group keys so no stale roster can be reused.
    s.put('sessions_out',outgoing);
    s.put('sessions_in',incoming);
    s.put('groups_in',groups);
    s.put('groups_out',<String,dynamic>{});
    s.put('group_pending',<String,dynamic>{});
    s.put('processed_sender_keys',<String,dynamic>{});
    // A verified identity replacement invalidates uncommitted plaintext
    // recovery buffers from the previous trust decision as well.
    s.put('decryption_pending',<String,dynamic>{});
    await _save(s);
  }

  Future<OrbitCipherEnvelope> _sealOne(
      _NativeState s,String recipient,OrbitMessagingRemoteDevice remote,
      String conversation,int epoch,String kind,Map<String,dynamic> payload,
      ) async {
    await _pin(s,recipient,remote);
    final out=s.bucket('sessions_out');
    var record=out[remote.id] is Map
      ?Map<String,dynamic>.from(out[remote.id] as Map):null;
    if(record!=null){
      if(record['fingerprint']!=remote.fingerprint ||
          record['key_version']!=remote.keyVersion ||
          record['curve']!=remote.signedPrekey){
        throw OrbitMessagingSecurityException(
          'A trusted recipient device changed keys. Review before sending.',409);
      }
    }else{
      // Claim an X3DH one-time key ONLY when a new Olm session is required.
      final fresh=await _api.discoverKeys(recipient,
        consumeOneTimePrekey:true);
      final matching=fresh.devices.where((d)=>d.id==remote.id).toList();
      if(matching.length!=1||matching.single.oneTimePublic==null){
        throw OrbitMessagingSecurityException(
          'Recipient has no available one-time messaging prekey.',409);
      }
      final claimed=matching.single;
      await _pin(s,recipient,claimed);
      final initial=_native.invoke({
        'op':'session_outbound','pickle_key_b64':s.key,
        'account_pickle':s.data['account'],
        'recipient_curve_b64':claimed.signedPrekey,
        'recipient_one_time_b64':claimed.oneTimePublic,
      });
      record={
        'pickle':initial['session_pickle'],
        'sid':initial['session_id'],'curve':claimed.signedPrekey,
        'fingerprint':claimed.fingerprint,
        'key_version':claimed.keyVersion,
      };
    }
    final encrypted=_native.invoke({
      'op':'session_encrypt','pickle_key_b64':s.key,
      'session_pickle':record['pickle'],
      'plaintext_b64':base64Encode(utf8.encode(jsonEncode(payload))),
    });
    record['pickle']=encrypted['session_pickle'];
    out[remote.id]=record;
    s.put('sessions_out',out);
    final public=Map<String,dynamic>.from(s.data['public'] as Map);
    final header={
      'v':1,'type':'olm','protocol':protocol,
      'cid':conversation,'epoch':epoch,'kind':kind,
      'sender':s.owner,'sender_device':s.device,
      'sender_identity':public['identity_ed25519'],
      'sender_curve':public['signed_prekey_x25519'],
      'recipient_device':remote.id,
      'message_type':encrypted['message_type'],
      'session_id':encrypted['session_id'],
    };
    return OrbitCipherEnvelope(
      deviceId:remote.id,
      ciphertextB64:encrypted['ciphertext_b64'] as String,
      headerB64:base64Encode(utf8.encode(jsonEncode(header))));
  }

  Future<List<OrbitCipherEnvelope>> _sealAll(
      _NativeState s,Map<String,OrbitMessagingKeyDirectory> recipients,
      String conversation,int epoch,String kind,
      Map<String,dynamic> payload) async {
    final envelopes=<OrbitCipherEnvelope>[];
    final ids=<String>{};
    for(final directory in recipients.values){
      for(final remote in directory.devices){
        if(!ids.add(remote.id)){
          throw OrbitMessagingSecurityException(
            'Duplicate recipient device in authenticated roster.',409);
        }
        envelopes.add(await _sealOne(s,directory.userId,remote,
          conversation,epoch,kind,payload));
      }
    }
    if(envelopes.isEmpty)throw OrbitMessagingSecurityException(
      'No approved recipient devices.',409);
    return envelopes;
  }

  Map<String,dynamic> _header(String raw) {
    final decoded=jsonDecode(utf8.decode(base64Decode(raw)));
    if(decoded is! Map)throw OrbitMessagingSecurityException(
      'Encrypted ratchet header is invalid.',409);
    return Map<String,dynamic>.from(decoded);
  }

  Future<Map<String,dynamic>> _openOlm(
      _NativeState s,OrbitMailboxEnvelope envelope,
      String conversation,{bool remember=false}) async {
    final header=_header(envelope.headerB64);
    if(header['v']!=1||header['type']!='olm'||
        header['protocol']!=protocol||
        envelope.protocol!=protocol||
        header['cid']!=conversation||
        header['epoch']!=envelope.groupEpoch||
        header['sender']!=envelope.senderId||
        header['sender_device']!=envelope.senderDeviceId||
        header['recipient_device']!=s.device||
        header['kind']!=envelope.kind) {
      throw OrbitMessagingSecurityException(
        'Encrypted message scope or recipient device changed.',409);
    }
    final directory=await _api.discoverKeys(envelope.senderId,
      consumeOneTimePrekey:false);
    final candidates=directory.devices.where(
      (d)=>d.id==envelope.senderDeviceId).toList();
    if(candidates.length!=1)throw OrbitMessagingSecurityException(
      'Authenticated sender device is no longer trusted.',409);
    final remote=candidates.single;
    await _pin(s,directory.userId,remote);
    if(header['sender_identity']!=remote.identity ||
        header['sender_curve']!=remote.signedPrekey){
      throw OrbitMessagingSecurityException(
        'Authenticated sender identity did not match directory.',409);
    }
    final sid=header['session_id'];
    final msgType=header['message_type'];
    if(sid is! String || msgType is! int || (msgType!=0&&msgType!=1)){
      throw OrbitMessagingSecurityException(
        'Malformed Olm session header.',409);
    }
    final inKey='${remote.id}|$sid';
    final inbound=s.bucket('sessions_in');
    final outbound=s.bucket('sessions_out');
    final known=inbound[inKey] is Map
      ?Map<String,dynamic>.from(inbound[inKey] as Map):null;
    final out=outbound[remote.id] is Map
      ?Map<String,dynamic>.from(outbound[remote.id] as Map):null;
    // A sender receives its own other-device/same-device mailbox copy.
    // Its outbound chain cannot decrypt a copy sent to itself; establish
    // the matching inbound prekey chain instead.
    final isOutbound=known==null && out!=null && out['sid']==sid &&
      remote.id!=s.device;
    final record=known??(isOutbound?out:null);
    late Map<String,dynamic> decrypted;
    if(record!=null){
      decrypted=_native.invoke({
        'op':'session_decrypt','pickle_key_b64':s.key,
        'session_pickle':record['pickle'],
        'message_type':msgType,
        'ciphertext_b64':envelope.ciphertextB64,
      });
      record['pickle']=decrypted['session_pickle'];
      if(isOutbound)outbound[remote.id]=record;
      else inbound[inKey]=record;
    }else{
      if(msgType!=0)throw OrbitMessagingSecurityException(
        'No authenticated Olm prekey session exists.',409);
      decrypted=_native.invoke({
        'op':'session_inbound','pickle_key_b64':s.key,
        'account_pickle':s.data['account'],
        'sender_curve_b64':remote.signedPrekey,
        'message_type':msgType,
        'ciphertext_b64':envelope.ciphertextB64,
      });
      s.data['account']=decrypted['account_pickle'];
      inbound[inKey]={
        'pickle':decrypted['session_pickle'],'sid':sid,
        'curve':remote.signedPrekey,
        'fingerprint':remote.fingerprint,
        'key_version':remote.keyVersion,
      };
    }
    s.put('sessions_in',inbound);
    s.put('sessions_out',outbound);
    final plaintext=jsonDecode(utf8.decode(
      base64Decode(decrypted['plaintext_b64'] as String)));
    if(plaintext is! Map)throw OrbitMessagingSecurityException(
      'Authenticated Olm payload is invalid.',409);
    final data=Map<String,dynamic>.from(plaintext);
    if(data['cid']!=conversation||data['epoch']!=envelope.groupEpoch||
        data['kind']!=envelope.kind||data['sender']!=envelope.senderId||
        data['sender_device']!=envelope.senderDeviceId){
      throw OrbitMessagingSecurityException(
        'Authenticated Olm payload is outside its conversation.',409);
    }
    if(remember){
      final p=s.bucket('decryption_pending');
      p[envelope.id]={
        'conversation':conversation,
        'message_id':envelope.messageId,
        'plaintext_b64':data['body_b64'],
      };
      if(p.length>160)throw OrbitMessagingSecurityException(
        'Too many uncommitted encrypted message decryptions.',503);
      s.put('decryption_pending',p);
    }
    return data;
  }

  @override
  Future<void> prepareGroupEpoch({
    required String conversationId,
    required int groupEpoch,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  }) async {
    final s=await _open();
    await _ensureAccount(s);
    final roster=<String>[];
    for(final directory in recipients.values){
      for(final d in directory.devices){
        await _pin(s,directory.userId,d);
        roster.add('${directory.userId}|${d.id}|${d.fingerprint}|'+
          d.keyVersion.toString());
      }
    }
    roster.sort();
    final fingerprint=hashes.sha256.convert(
      utf8.encode(roster.join('\n'))).toString();
    final groups=s.bucket('groups_out');
    final ready=groups[conversationId] is Map
      ?Map<String,dynamic>.from(groups[conversationId] as Map):null;
    if(ready!=null && ready['epoch']==groupEpoch &&
        ready['roster']==fingerprint &&
        !s.bucket('group_pending').containsKey(conversationId)){
      return;
    }

    final pending=s.bucket('group_pending');
    Map<String,dynamic> packet;
    final existing=pending[conversationId] is Map
      ?Map<String,dynamic>.from(pending[conversationId] as Map):null;
    if(existing!=null && existing['epoch']==groupEpoch &&
        existing['roster']==fingerprint){
      packet=existing;
    }else{
      // Every membership, consent or trusted-device change creates a
      // completely new Megolm sender ratchet and fresh Olm key envelopes.
      final group=_native.invoke({
        'op':'group_create','pickle_key_b64':s.key,
      });
      // This sending device owns the new Megolm session. Provision a local
      // authenticated inbound copy so its own delivered envelope can also
      // be decrypted. Other devices still require Olm-wrapped distribution.
      final selfKey='${s.device}|${group['session_id']}';
      final imported=_native.invoke({
        'op':'group_import','pickle_key_b64':s.key,
        'session_key':group['session_key'],
      });
      final inbox=s.bucket('groups_in');
      inbox[selfKey]={
        'conversation':conversationId,'epoch':groupEpoch,
        'pickle':imported['inbound_pickle'],
      };
      s.put('groups_in',inbox);
      final wrappedPayload={
        't':'sender_key','cid':conversationId,'epoch':groupEpoch,
        'kind':'sender_key','sender':s.owner,'sender_device':s.device,
        'session_id':group['session_id'],
        'session_key':group['session_key'],
      };
      final encrypted=await _sealAll(s,recipients,conversationId,
        groupEpoch,'sender_key',wrappedPayload);
      final clientId=const Uuid().v4();
      packet={
        'client_id':clientId,'epoch':groupEpoch,'roster':fingerprint,
        'group_pickle':group['group_pickle'],
        'session_id':group['session_id'],
        'session_key':group['session_key'],
        'envelopes':encrypted.map((e)=>e.toJson()).toList(),
      };
      pending[conversationId]=packet;
      s.put('group_pending',pending);
      // Ratchet advances and pending immutable ciphertext are one protected
      // owner/device snapshot; a timeout retries the same client ID.
      await _save(s);
    }
    final raw=packet['envelopes'] as List;
    final result=await _api.distributeCircleSenderKey(conversationId,
      clientId:packet['client_id'] as String,groupEpoch:groupEpoch,
      protocol:protocol,
      envelopes:raw.map((e){
        final value=Map<String,dynamic>.from(e as Map);
        return OrbitCipherEnvelope(
          deviceId:value['device_id'] as String,
          ciphertextB64:value['ciphertext_b64'] as String,
          headerB64:value['protocol_header_b64'] as String);
      }).toList(growable:false));
    if(!result.stored||result.groupEpoch!=groupEpoch){
      throw OrbitMessagingSecurityException(
        'Circle sender-key rotation was not acknowledged.',503);
    }
    groups[conversationId]={
      'epoch':groupEpoch,'roster':fingerprint,
      'group_pickle':packet['group_pickle'],
      'session_id':packet['session_id'],
      'session_key':packet['session_key'],
    };
    pending.remove(conversationId);
    s.put('groups_out',groups);s.put('group_pending',pending);
    await _save(s);
  }

  @override
  Future<OrbitEncryptedSend> encrypt({
    required String conversationId,required int groupEpoch,
    required String kind,required Uint8List plaintext,
    required Map<String,OrbitMessagingKeyDirectory> recipients,
  }) async {
    final s=await _open();
    await _ensureAccount(s);
    if(plaintext.isEmpty||plaintext.length>22000){
      throw OrbitMessagingSecurityException(
        'Encrypted message exceeds the maximum plaintext size.',422);
    }
    final groups=s.bucket('groups_out');
    final group=groups[conversationId] is Map
      ?Map<String,dynamic>.from(groups[conversationId] as Map):null;
    final payload={
      't':group==null?'direct':'group','cid':conversationId,
      'epoch':groupEpoch,'kind':kind,'sender':s.owner,
      'sender_device':s.device,'body_b64':base64Encode(plaintext),
    };
    if(group==null){
      final envelopes=await _sealAll(s,recipients,conversationId,
        groupEpoch,kind,payload);
      await _save(s); // atomic state advance BEFORE ciphertext leaves
      return OrbitEncryptedSend(protocol:protocol,kind:kind,
        groupEpoch:groupEpoch,envelopes:envelopes);
    }
    if(group['epoch']!=groupEpoch ||
        s.bucket('group_pending').containsKey(conversationId)){
      throw OrbitMessagingSecurityException(
        'Circle sender keys must rotate before sending.',409);
    }
    final encrypted=_native.invoke({
      'op':'group_encrypt','pickle_key_b64':s.key,
      'group_pickle':group['group_pickle'],
      'plaintext_b64':base64Encode(utf8.encode(jsonEncode(payload))),
    });
    group['group_pickle']=encrypted['group_pickle'];
    groups[conversationId]=group;s.put('groups_out',groups);
    await _save(s);
    final header=base64Encode(utf8.encode(jsonEncode({
      'v':1,'type':'megolm','protocol':protocol,
      'cid':conversationId,'epoch':groupEpoch,'kind':kind,
      'sender':s.owner,'sender_device':s.device,
      'session_id':group['session_id'],
    })));
    final devices=<String>{};
    final packets=<OrbitCipherEnvelope>[];
    for(final directory in recipients.values){
      for(final d in directory.devices){
        if(!devices.add(d.id))throw OrbitMessagingSecurityException(
          'Duplicate authenticated group recipient device.',409);
        packets.add(OrbitCipherEnvelope(
          deviceId:d.id,headerB64:header,
          ciphertextB64:base64Encode(utf8.encode(
            encrypted['message_b64'] as String))));
      }
    }
    return OrbitEncryptedSend(protocol:protocol,kind:kind,
      groupEpoch:groupEpoch,envelopes:packets);
  }

  @override
  Future<void> refreshGroupKeys(
      String conversationId,int groupEpoch) async {
    final s=await _open();
    await _ensureAccount(s);
    String? cursor;
    for(var pageNumber=0;pageNumber<5;pageNumber++){
      final page=await _api.circleSenderKeys(conversationId,
        cursor:cursor,limit:100);
      if(page.groupEpoch!=groupEpoch)throw OrbitMessagingSecurityException(
        'Circle key directory epoch changed.',409);
      for(final distribution in page.items.reversed){
        if(distribution.groupEpoch!=groupEpoch ||
           distribution.protocol!=protocol)continue;
        final processed=s.bucket('processed_sender_keys');
        if(processed.containsKey(distribution.id))continue;
        if(distribution.senderDeviceId==s.device){
          // Sender's own inbound Megolm copy was committed when the
          // outbound chain was created; fail if its session was lost.
          final group=s.bucket('groups_out')[conversationId];
          if(group is! Map || group['epoch']!=groupEpoch ||
              !s.bucket('groups_in').containsKey(
                '${s.device}|${group['session_id']}')){
            throw OrbitMessagingSecurityException(
              'Local authenticated Circle sender-key state is missing.',409);
          }
          processed[distribution.id]=groupEpoch;
          s.put('processed_sender_keys',processed);
          await _save(s);
          continue;
        }
        final env=OrbitMailboxEnvelope(
          id:distribution.id,messageId:distribution.id,
          senderId:distribution.senderId,
          senderDeviceId:distribution.senderDeviceId,
          kind:'sender_key',protocol:distribution.protocol,
          groupEpoch:distribution.groupEpoch,
          keyVersion:distribution.recipientKeyVersion,
          ciphertextB64:distribution.ciphertextB64,
          headerB64:distribution.headerB64,
          createdAt:DateTime.now().toUtc());
        final opened=await _openOlm(s,env,conversationId);
        if(opened['t']!='sender_key' ||
            opened['session_key'] is! String ||
            opened['session_id'] is! String){
          throw OrbitMessagingSecurityException(
            'Untrusted Circle sender-key distribution.',409);
        }
        final id='${distribution.senderDeviceId}|${opened['session_id']}';
        final received=s.bucket('groups_in');
        if(!received.containsKey(id)){
          final imported=_native.invoke({
            'op':'group_import','pickle_key_b64':s.key,
            'session_key':opened['session_key'],
          });
          received[id]={
            'conversation':conversationId,'epoch':groupEpoch,
            'pickle':imported['inbound_pickle'],
          };
          s.put('groups_in',received);
        }
        final processed=s.bucket('processed_sender_keys');
        processed[distribution.id]=groupEpoch;
        if(processed.length>1000){
          throw OrbitMessagingSecurityException(
            'Circle key history requires safe archival before continuing.',503);
        }
        s.put('processed_sender_keys',processed);
        await _save(s);
      }
      cursor=page.nextCursor;
      if(cursor==null)break;
    }
  }

  @override
  Future<Uint8List> decrypt({
    required OrbitMailboxEnvelope envelope,
    required String conversationId,
  }) async {
    final s=await _open();
    await _ensureAccount(s);
    final pending=s.bucket('decryption_pending');
    final cached=pending[envelope.id] is Map
      ?Map<String,dynamic>.from(pending[envelope.id] as Map):null;
    if(cached!=null){
      if(cached['conversation']!=conversationId ||
          cached['message_id']!=envelope.messageId){
        throw OrbitMessagingSecurityException(
          'Replayed envelope does not match the authenticated recipient.',409);
      }
      return Uint8List.fromList(
        base64Decode(cached['plaintext_b64'] as String));
    }
    final header=_header(envelope.headerB64);
    if(header['type']=='olm'){
      final payload=await _openOlm(s,envelope,conversationId,remember:true);
      if(payload['t']!='direct'||payload['body_b64'] is! String){
        throw OrbitMessagingSecurityException(
          'Invalid Olm user-message content type.',409);
      }
      await _save(s);
      return Uint8List.fromList(base64Decode(payload['body_b64'] as String));
    }
    if(header['type']!='megolm'||header['protocol']!=protocol ||
        header['cid']!=conversationId||
        header['epoch']!=envelope.groupEpoch||
        header['sender']!=envelope.senderId||
        header['sender_device']!=envelope.senderDeviceId||
        header['kind']!=envelope.kind){
      throw OrbitMessagingSecurityException(
        'Authenticated Circle message scope changed.',409);
    }
    final id='${envelope.senderDeviceId}|${header['session_id']}';
    final groups=s.bucket('groups_in');
    final stored=groups[id] is Map
      ?Map<String,dynamic>.from(groups[id] as Map):null;
    if(stored==null||stored['conversation']!=conversationId ||
        stored['epoch']!=envelope.groupEpoch){
      throw OrbitMessagingSecurityException(
        'Authenticated Circle sender-key packet has not been received.',409);
    }
    final result=_native.invoke({
      'op':'group_decrypt','pickle_key_b64':s.key,
      'inbound_pickle':stored['pickle'],
      'message_b64':utf8.decode(base64Decode(envelope.ciphertextB64)),
    });
    final payload=jsonDecode(utf8.decode(
      base64Decode(result['plaintext_b64'] as String)));
    if(payload is! Map ||
        payload['t']!='group' ||
        payload['cid']!=conversationId||
        payload['epoch']!=envelope.groupEpoch||
        payload['kind']!=envelope.kind||
        payload['sender']!=envelope.senderId||
        payload['sender_device']!=envelope.senderDeviceId||
        payload['body_b64'] is! String){
      throw OrbitMessagingSecurityException(
        'Decrypted Circle content is not bound to current participants.',409);
    }
    stored['pickle']=result['inbound_pickle'];
    groups[id]=stored;s.put('groups_in',groups);
    pending[envelope.id]={
      'conversation':conversationId,'message_id':envelope.messageId,
      'plaintext_b64':payload['body_b64'],
    };
    if(pending.length>160)throw OrbitMessagingSecurityException(
      'Too many uncommitted decrypted messages.',503);
    s.put('decryption_pending',pending);
    await _save(s);
    return Uint8List.fromList(base64Decode(payload['body_b64'] as String));
  }

  @override
  Future<void> confirmStoredDecryption(String envelopeId) async {
    final s=await _open();
    final pending=s.bucket('decryption_pending');
    if(pending.remove(envelopeId)!=null){
      s.put('decryption_pending',pending);
      await _save(s);
    }
  }

  @override
  Future<void> purgeForOwner(String owner) async {
    _lastPrekeyCheck.removeWhere((key,_)=>key.startsWith('$owner|'));
    await _store.purgeOwner(owner);
  }
}
