import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart' as hashes;
import 'package:uuid/uuid.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../messaging/data/orbit_messaging_api.dart';
import '../../messaging/data/orbit_messaging_local_vault.dart';
import '../../messaging/data/orbit_messaging_models.dart';
import '../../messaging/data/orbit_messaging_vodozemac_cipher.dart';
import 'orbit_relay_api.dart';
import 'orbit_relay_protocol.dart';
import 'orbit_relay_transport.dart';
import 'orbit_relay_vault.dart';

/// Explicit, single-conversation foreground opt-in. Authorization and
/// monotonic time remain memory-only; restart requires new online leases.
class OrbitRelaySession {
  OrbitRelaySession({required this.messaging,required this.cipher,
      OrbitRelayTransport? transport,OrbitRelayVault? vault}):
      api=OrbitRelayApi(messaging:messaging),_transport=transport??OrbitRelayTransport(),
      _vault=vault??OrbitRelayVault();
  final OrbitMessagingApi messaging;
  final OrbitMessagingVodozemacCipher cipher;
  final OrbitRelayApi api;
  final OrbitRelayTransport _transport;
  final OrbitRelayVault _vault;
  OrbitRelayCapabilities? _cap;
  OrbitConversation? _thread;
  String? _owner,_device,_rosterHash;
  Map<String,OrbitMessagingKeyDirectory> _directories={};
  Map<String,OrbitMessagingRemoteDevice> _keys={};
  List<OrbitRelayLease> _leases=[];
  final Map<String,OrbitRelayLease> _incomingLeases={};
  int _generation=0;
  Future<void> _receiveTail=Future.value();
  bool get active=>_transport.running&&_cap!=null&&_leases.any((l)=>l.live(_cap!));
  bool canUse(String scope,String owner)=>active&&_thread?.id==scope&&_owner==owner;
  String get device=>_device!;
  Map<String,OrbitMessagingKeyDirectory> get recipients=>Map.unmodifiable(_directories);
  static String rosterHash(Map<String,OrbitMessagingKeyDirectory> directories){
    final devices=directories.values.expand((d)=>d.devices).toList()
      ..sort((a,b)=>a.id.compareTo(b.id));
    return relayHash(devices.map((d)=>[d.id,d.keyVersion,
      hashes.sha256.convert(utf8.encode(d.identity)).toString()]).toList());
  }
  Future<void> start(OrbitConversation thread,
      Map<String,OrbitMessagingKeyDirectory> directories) async {
    await stop();
    final generation=_generation;
    relayCheck(cipher.independentlyVerified&&thread.kind=='direct'&&thread.peerId!=null,'Relay unavailable.');
    final owner=await messaging.owner;
    final local=await OrbitIdentityClient.instance.trustedMediaDevice();
    final cap=OrbitRelayCapabilities.fromJson(await api.capabilities());
    relayCheck(cap.ready&&generation==_generation,'Relay unavailable.');
    final own=directories[owner]?.devices.where((d)=>d.id==local.id).toList()??[];
    final peers=directories[thread.peerId]?.devices??[];
    final all=directories.values.expand((d)=>d.devices).toList();
    relayCheck(own.length==1&&peers.isNotEmpty&&all.length<=12&&
      all.map((d)=>d.id).toSet().length==all.length,'Relay roster unavailable.');
    final roster=rosterHash(directories);
    await cipher.prepareRelayDirect(owner:owner,device:local.id,recipients:directories);
    final leases=<OrbitRelayLease>[];
    for(final peer in peers.take(10)){
      final raw=await api.lease(scope:thread.id,peer:peer.id,keyVersion:own.single.keyVersion,nonce:relayNonce());
      final lease=await OrbitRelayLease.verify(raw['lease'] as String,cap,scope:thread.id,localDevice:local.id,receiving:false);
      relayCheck(lease.id==raw['lease_id']&&lease.peer==peer.id&&lease.peerKey==peer.identity&&
        lease.senderKey==own.single.identity&&lease.epoch==thread.groupEpoch&&lease.claims['roster_hash']==roster&&
        lease.claims['sender_key_version']==own.single.keyVersion&&lease.claims['peer_key_version']==peer.keyVersion,
        'Relay lease directory mismatch.');
      leases.add(lease);
    }
    relayCheck(generation==_generation&&await messaging.owner==owner&&leases.isNotEmpty,'Relay account changed.');
    _cap=cap;_thread=thread;_owner=owner;_device=local.id;_rosterHash=roster;
    _directories=Map.of(directories);_keys={for(final d in all)d.id:d};_leases=leases;
    try{
      await _transport.start(sign:(message)=>_sign(generation,message),
        accept:(packet,transcript)=>_serialAccept(generation,packet,transcript),
        duration:Duration(seconds:leases.map((l)=>l.expires-cap.clock.seconds).reduce((a,b)=>a<b?a:b).clamp(1,900).toInt()));
    }catch(_){await stop();rethrow;}
    if(generation!=_generation){await stop();throw const FormatException('Relay session closed.');}
  }
  Future<void> _current(int generation) async {
    relayCheck(generation==_generation&&active&&_owner!=null&&
      await messaging.owner==_owner,'Relay session unavailable.');
  }
  Future<String> _sign(int generation,String message) async {
    await _current(generation);
    final result=await cipher.signRelayProof(_owner!,_device!,message);
    await _current(generation);return result;
  }
  Future<Map<String,Object?>> _serialAccept(int generation,Map<String,dynamic> packet,String transcript) async {
    final previous=_receiveTail,done=Completer<void>();
    _receiveTail=done.future;
    try{await previous;return await _accept(generation,packet,transcript);}
    finally{done.complete();}
  }
  Future<Map<String,Object?>> _accept(int generation,Map<String,dynamic> packet,String transcript) async {
    await _current(generation);
    final cap=_cap!,owner=_owner!,device=_device!,thread=_thread!;
    relayCheck(packet.length==8&&packet.keys.every(const {'lease','envelope_id','source_client_id','digest','peer_digest','source','peer_envelope','sender_proof'}.contains),'Invalid Relay packet.');
    final lease=await OrbitRelayLease.verify(packet['lease'] as String,cap,scope:thread.id,localDevice:device,receiving:true);
    final sender=_keys[lease.sender],self=_keys[device];
    relayCheck(sender!=null&&self!=null&&_directories[thread.peerId]!.devices.any((d)=>d.id==lease.sender)&&
      sender.identity==lease.senderKey&&self.identity==lease.peerKey&&
      sender.keyVersion==lease.claims['sender_key_version']&&self.keyVersion==lease.claims['peer_key_version']&&
      lease.claims['roster_hash']==_rosterHash&&lease.epoch==thread.groupEpoch,'Relay peer keys changed.');
    final id=packet['envelope_id'] as String,client=packet['source_client_id'] as String,
      digest=packet['digest'] as String,peerDigest=packet['peer_digest'] as String;
    // Stable IDs/digests are signed and validated before local persistence.
    relayCheck(relayUuid(id)&&relayUuid(client)&&RegExp(r'^[0-9a-f]{64}
      'Invalid Relay identity.');
    final source=relayMap(packet['source']);
    relayCheck(source.length==4&&source.keys.every(const {'client_id','kind','protocol','group_epoch'}.contains)&&source['client_id']==client&&source['group_epoch']==lease.epoch,'Relay source mismatch.');
    final envelope=relayMap(packet['peer_envelope']);
    relayCheck(envelope['device_id']==device&&relayPeerDigest(thread.id,source,envelope,cap.frameBytes)==peerDigest,
      'Relay ciphertext mismatch.');
    relayCheck(await relayVerify('orbit-relay-sender-v1|$transcript|'+lease.id+'|$id|$digest|$peerDigest',
      packet['sender_proof'] as String,lease.senderKey),'Relay sender proof invalid.');
    final header=relayMap(jsonDecode(utf8.decode(base64Decode(envelope['protocol_header_b64'] as String))));
    relayCheck(header['v']==1&&header['type']=='olm'&&header['protocol']==orbitRelayMessageProtocol&&
      header['cid']==thread.id&&header['epoch']==lease.epoch&&header['kind']==source['kind']&&
      header['sender']==thread.peerId&&header['sender_device']==lease.sender&&
      header['sender_identity']==sender!.identity&&header['sender_curve']==sender.signedPrekey&&
      header['recipient_device']==device,'Relay encrypted scope mismatch.');
    final recordId='in:$id';
    final old=await _vault.get(owner,device,recordId,now:cap.clock.seconds);
    if(old!=null){
      relayCheck(old['digest']==digest&&old['peer_digest']==peerDigest&&old['lease_id']==lease.id&&
        old['source_client_id']==client,'Relay replay conflict.');
      _incomingLeases[recordId]=lease;
      return Map<String,Object?>.from(relayMap(old['receipt']));
    }
    final received=math.max(cap.clock.seconds,lease.issued);
    relayCheck(received<lease.expires,'Relay lease expired.');
    final receipt={'nonce':id,'received_at':received,'peer_digest':peerDigest,
      'signature_b64':await _sign(generation,relayReceiptInput(lease,id,client,digest,peerDigest,received))};
    await _current(generation);
    // Receipt attests durable encrypted device receipt, NOT successful
    // Olm decryption, read, source acceptance, or canonical history.
    await _vault.put(owner,device,recordId,{'lease_id':lease.id,'digest':digest,
      'source_client_id':client,'peer_digest':peerDigest,'source':source,'peer_envelope':envelope,'receipt':receipt},
      expiry:lease.expires+7*86400);
    await _current(generation);
    _incomingLeases[recordId]=lease;
    return receipt;
  }
  /// Decrypt only in this live lease session under the M13 owner crypto
  /// lock. Local previews are not canonical history or read receipts.
  Future<List<OrbitLocalDecryptedMessage>> incoming() async {
    final generation=_generation,cap=_cap,owner=_owner,device=_device,thread=_thread;
    if(cap==null||owner==null||device==null||thread==null||!active)return [];
    final results=<OrbitLocalDecryptedMessage>[];
    for(final entry in Map<String,OrbitRelayLease>.of(_incomingLeases).entries){
      await _current(generation);
      final lease=entry.value;
      if(!lease.live(cap))continue;
      final record=await _vault.get(owner,device,entry.key,now:cap.clock.seconds);
      if(record==null)continue;
      final source=relayMap(record['source']),peer=relayMap(record['peer_envelope']);
      final receipt=relayMap(record['receipt']);
      final client=record['source_client_id'] as String;
      final localId='local-relay-$client';
      final envelope=OrbitMailboxEnvelope(id:localId,messageId:localId,
        senderId:thread.peerId!,senderDeviceId:lease.sender,kind:source['kind'] as String,
        protocol:orbitRelayMessageProtocol,groupEpoch:lease.epoch,keyVersion:lease.claims['peer_key_version'] as int,
        ciphertextB64:peer['ciphertext_b64'] as String,headerB64:peer['protocol_header_b64'] as String,
        createdAt:DateTime.fromMillisecondsSinceEpoch((receipt['received_at'] as int)*1000,isUtc:true));
      try{
        final clear=await cipher.decryptRelayDirect(owner:owner,device:device,envelope:envelope,
          conversationId:thread.id,directory:_directories[thread.peerId]!);
        await _current(generation);
        results.add(OrbitLocalDecryptedMessage(id:localId,conversationId:thread.id,senderId:thread.peerId!,
          kind:envelope.kind,text:utf8.decode(clear),createdAt:envelope.createdAt));
      }catch(_){/* Durable ciphertext remains for ordinary authenticated sync. */}
    }
    results.sort((a,b)=>a.createdAt.compareTo(b.createdAt));return results;
  }
  /// Existing M13 outbox owns stable client ID and all device ciphertext.
  /// Relay stores only a receipt checkpoint; no fresh encryption or duplicate
  /// source IDs on retry. One recipient receipt per logical message.
  Future<bool> transfer(OrbitQueuedCiphertext queued) async {
    final generation=_generation,owner=_owner,device=_device,cap=_cap;
    if(owner==null||device==null||cap==null||!canUse(queued.conversationId,owner)||
       !orbitRelayKinds.contains(queued.kind)||queued.protocol!=orbitRelayMessageProtocol)return false;
    await _current(generation);
    final recordId='out:'+queued.clientId;
    if(await _vault.get(owner,device,recordId,now:cap.clock.seconds)!=null)return true;
    final source=Map<String,dynamic>.from(queued.toJson())..remove('conversation_id');
    final digest=relaySourceDigest(queued.conversationId,source,cap.frameBytes);
    for(final lease in _leases){
      if(!lease.live(cap)||queued.groupEpoch!=lease.epoch)continue;
      final matches=queued.envelopes.where((e)=>e.deviceId==lease.peer).toList();
      if(matches.length!=1)continue;
      final envelope=Map<String,dynamic>.from(matches.single.toJson());
      final pd=relayPeerDigest(lease.scope,source,envelope,cap.frameBytes);
      final packet=<String,Object?>{'lease':lease.token,'envelope_id':queued.clientId,
        'source_client_id':queued.clientId,'digest':digest,'peer_digest':pd,
        'source':Map<String,dynamic>.from(source)..remove('envelopes'),'peer_envelope':envelope};
      final proof=await _transport.transfer(lease,packet,(message)=>_sign(generation,message));
      if(proof==null)continue;
      final received=proof['received_at'];
      if(proof.length!=4||!proof.keys.every(const {'nonce','received_at','peer_digest','signature_b64'}.contains)||proof['nonce']!=queued.clientId||proof['peer_digest']!=pd||received is! int||
          received<lease.issued||received>=lease.expires||
          !await relayVerify(relayReceiptInput(lease,queued.clientId,queued.clientId,digest,pd,received),
            proof['signature_b64'] as String,lease.peerKey))continue;
      await _current(generation);
      await _vault.put(owner,device,recordId,{'lease_id':lease.id,'envelope_id':queued.clientId,
        'source_client_id':queued.clientId,'digest':digest,'source_envelope':source,'receipt':proof,
        'roster_hash':_rosterHash,'lease_expires':lease.expires},expiry:lease.expires+7*86400);
      return true;
    }
    return false;
  }
  Future<void> stop({bool revoke=false}) async {
    final old=List<OrbitRelayLease>.of(_leases);
    _generation++;_cap=null;_thread=null;_owner=null;_device=null;_rosterHash=null;
    _directories={};_keys={};_leases=[];_incomingLeases.clear();
    await _transport.stop();
    if(revoke){for(final lease in old){try{await api.revoke(lease.id,reason:'opt_out');}catch(_){}}}
  }
}

/// On reconnect, attempt source-authoritative reconciliation before ordinary
/// HTTPS. An expired or unavailable Relay lease never blocks the existing
/// messaging queue; the caller revalidates the current roster before fallback.
class OrbitRelayReconcile {
  OrbitRelayReconcile({required this.messaging,OrbitRelayVault? vault}):
    api=OrbitRelayApi(messaging:messaging),_vault=vault??OrbitRelayVault();
  final OrbitMessagingApi messaging;
  final OrbitRelayApi api;
  final OrbitRelayVault _vault;
  Future<String?> publish(OrbitQueuedCiphertext queued,String owner,String device,
      {required String currentRoster}) async {
    final id='out:'+queued.clientId;
    final record=await _vault.get(owner,device,id,now:DateTime.now().toUtc().millisecondsSinceEpoch~/1000);
    if(record==null)return null;
    relayCheck(record['roster_hash']==currentRoster,'Relay roster changed; review required.');
    final body=Map<String,Object?>.from(record)..remove('roster_hash')..remove('lease_expires');
    final response=await api.reconcile(const Uuid().v4(),[body]);
    final rows=response['results'];
    relayCheck(rows is List&&rows.length==1,'Invalid Relay acknowledgement.');
    final result=relayMap((rows as List).single);
    relayCheck(result['envelope_id']==queued.clientId,'Relay acknowledgement mismatch.');
    if(result['status']=='accepted'||result['status']=='duplicate'){
      relayCheck(result['source_ref'] is String,'Missing source acknowledgement.');
      // Remove only after M13 caller has acknowledged its own outbox.
      return result['source_ref'] as String;
    }
    if(result['status']=='expired'||result['status']=='retryable')return null;
    throw OrbitMessagingSecurityException('Relay authorization changed; review required.',409);
  }
  Future<Map<String,dynamic>?> checkpoint(String owner,String device,String clientId)=>
    _vault.get(owner,device,'out:'+clientId,now:DateTime.now().toUtc().millisecondsSinceEpoch~/1000);
  Future<void> clear(String owner,String device,String clientId)=>
    _vault.remove(owner,device,'out:'+clientId);
  /// Explicitly read own backend outcome page; never treat it as new
  /// authorization, a read acknowledgement or proof of peer plaintext.
  Future<Map<String,dynamic>> sync({String? cursor})=>api.sync(cursor:cursor);
}
).hasMatch(digest)&&RegExp(r'^[0-9a-f]{64}
      'Invalid Relay identity.');
    final source=relayMap(packet['source']);
    relayCheck(source['client_id']==client&&source['group_epoch']==lease.epoch,'Relay source mismatch.');
    final envelope=relayMap(packet['peer_envelope']);
    relayCheck(envelope['device_id']==device&&relayPeerDigest(thread.id,source,envelope,cap.frameBytes)==peerDigest,
      'Relay ciphertext mismatch.');
    relayCheck(await relayVerify('orbit-relay-sender-v1|$transcript|'+lease.id+'|$id|$digest|$peerDigest',
      packet['sender_proof'] as String,lease.senderKey),'Relay sender proof invalid.');
    final header=relayMap(jsonDecode(utf8.decode(base64Decode(envelope['protocol_header_b64'] as String))));
    relayCheck(header['v']==1&&header['type']=='olm'&&header['protocol']==orbitRelayMessageProtocol&&
      header['cid']==thread.id&&header['epoch']==lease.epoch&&header['kind']==source['kind']&&
      header['sender']==thread.peerId&&header['sender_device']==lease.sender&&
      header['sender_identity']==sender!.identity&&header['sender_curve']==sender.signedPrekey&&
      header['recipient_device']==device,'Relay encrypted scope mismatch.');
    final recordId='in:$id';
    final old=await _vault.get(owner,device,recordId,now:cap.clock.seconds);
    if(old!=null){
      relayCheck(old['digest']==digest&&old['peer_digest']==peerDigest&&old['lease_id']==lease.id&&
        old['source_client_id']==client,'Relay replay conflict.');
      _incomingLeases[recordId]=lease;
      return Map<String,Object?>.from(relayMap(old['receipt']));
    }
    final received=cap.clock.seconds;
    final receipt={'nonce':id,'received_at':received,'peer_digest':peerDigest,
      'signature_b64':await _sign(generation,relayReceiptInput(lease,id,client,digest,peerDigest,received))};
    await _current(generation);
    // Receipt attests durable encrypted device receipt, NOT successful
    // Olm decryption, read, source acceptance, or canonical history.
    await _vault.put(owner,device,recordId,{'lease_id':lease.id,'digest':digest,
      'source_client_id':client,'peer_digest':peerDigest,'source':source,'peer_envelope':envelope,'receipt':receipt},
      expiry:lease.expires+7*86400);
    await _current(generation);
    _incomingLeases[recordId]=lease;
    return receipt;
  }
  /// Decrypt only in this live lease session under the M13 owner crypto
  /// lock. Local previews are not canonical history or read receipts.
  Future<List<OrbitLocalDecryptedMessage>> incoming() async {
    final generation=_generation,cap=_cap,owner=_owner,device=_device,thread=_thread;
    if(cap==null||owner==null||device==null||thread==null||!active)return [];
    final results=<OrbitLocalDecryptedMessage>[];
    for(final entry in Map<String,OrbitRelayLease>.of(_incomingLeases).entries){
      await _current(generation);
      final lease=entry.value;
      if(!lease.live(cap))continue;
      final record=await _vault.get(owner,device,entry.key,now:cap.clock.seconds);
      if(record==null)continue;
      final source=relayMap(record['source']),peer=relayMap(record['peer_envelope']);
      final receipt=relayMap(record['receipt']);
      final client=record['source_client_id'] as String;
      final localId='local-relay-$client';
      final envelope=OrbitMailboxEnvelope(id:localId,messageId:localId,
        senderId:thread.peerId!,senderDeviceId:lease.sender,kind:source['kind'] as String,
        protocol:orbitRelayMessageProtocol,groupEpoch:lease.epoch,keyVersion:lease.claims['peer_key_version'] as int,
        ciphertextB64:peer['ciphertext_b64'] as String,headerB64:peer['protocol_header_b64'] as String,
        createdAt:DateTime.fromMillisecondsSinceEpoch((receipt['received_at'] as int)*1000,isUtc:true));
      try{
        final clear=await cipher.decryptRelayDirect(owner:owner,device:device,envelope:envelope,
          conversationId:thread.id,directory:_directories[thread.peerId]!);
        await _current(generation);
        results.add(OrbitLocalDecryptedMessage(id:localId,conversationId:thread.id,senderId:thread.peerId!,
          kind:envelope.kind,text:utf8.decode(clear),createdAt:envelope.createdAt));
      }catch(_){/* Durable ciphertext remains for ordinary authenticated sync. */}
    }
    results.sort((a,b)=>a.createdAt.compareTo(b.createdAt));return results;
  }
  /// Existing M13 outbox owns stable client ID and all device ciphertext.
  /// Relay stores only a receipt checkpoint; no fresh encryption or duplicate
  /// source IDs on retry. One recipient receipt per logical message.
  Future<bool> transfer(OrbitQueuedCiphertext queued) async {
    final generation=_generation,owner=_owner,device=_device,cap=_cap;
    if(owner==null||device==null||cap==null||!canUse(queued.conversationId,owner)||
       !orbitRelayKinds.contains(queued.kind)||queued.protocol!=orbitRelayMessageProtocol)return false;
    await _current(generation);
    final recordId='out:'+queued.clientId;
    if(await _vault.get(owner,device,recordId,now:cap.clock.seconds)!=null)return true;
    final source=Map<String,dynamic>.from(queued.toJson())..remove('conversation_id');
    final digest=relaySourceDigest(queued.conversationId,source,cap.frameBytes);
    for(final lease in _leases){
      if(!lease.live(cap)||queued.groupEpoch!=lease.epoch)continue;
      final matches=queued.envelopes.where((e)=>e.deviceId==lease.peer).toList();
      if(matches.length!=1)continue;
      final envelope=Map<String,dynamic>.from(matches.single.toJson());
      final pd=relayPeerDigest(lease.scope,source,envelope,cap.frameBytes);
      final packet=<String,Object?>{'lease':lease.token,'envelope_id':queued.clientId,
        'source_client_id':queued.clientId,'digest':digest,'peer_digest':pd,
        'source':Map<String,dynamic>.from(source)..remove('envelopes'),'peer_envelope':envelope};
      final proof=await _transport.transfer(lease,packet,(message)=>_sign(generation,message));
      if(proof==null)continue;
      final received=proof['received_at'];
      if(proof['nonce']!=queued.clientId||proof['peer_digest']!=pd||received is! int||
          received<lease.issued||received>=lease.expires||
          !await relayVerify(relayReceiptInput(lease,queued.clientId,queued.clientId,digest,pd,received),
            proof['signature_b64'] as String,lease.peerKey))continue;
      await _current(generation);
      await _vault.put(owner,device,recordId,{'lease_id':lease.id,'envelope_id':queued.clientId,
        'source_client_id':queued.clientId,'digest':digest,'source_envelope':source,'receipt':proof,
        'roster_hash':_rosterHash,'lease_expires':lease.expires},expiry:lease.expires+7*86400);
      return true;
    }
    return false;
  }
  Future<void> stop({bool revoke=false}) async {
    final old=List<OrbitRelayLease>.of(_leases);
    _generation++;_cap=null;_thread=null;_owner=null;_device=null;_rosterHash=null;
    _directories={};_keys={};_leases=[];_incomingLeases.clear();
    await _transport.stop();
    if(revoke){for(final lease in old){try{await api.revoke(lease.id,reason:'opt_out');}catch(_){}}}
  }
}

/// On reconnect, attempt source-authoritative reconciliation before ordinary
/// HTTPS. An expired or unavailable Relay lease never blocks the existing
/// messaging queue; the caller revalidates the current roster before fallback.
class OrbitRelayReconcile {
  OrbitRelayReconcile({required this.messaging,OrbitRelayVault? vault}):
    api=OrbitRelayApi(messaging:messaging),_vault=vault??OrbitRelayVault();
  final OrbitMessagingApi messaging;
  final OrbitRelayApi api;
  final OrbitRelayVault _vault;
  Future<String?> publish(OrbitQueuedCiphertext queued,String owner,String device,
      {required String currentRoster}) async {
    final id='out:'+queued.clientId;
    final record=await _vault.get(owner,device,id,now:DateTime.now().toUtc().millisecondsSinceEpoch~/1000);
    if(record==null)return null;
    relayCheck(record['roster_hash']==currentRoster,'Relay roster changed; review required.');
    final body=Map<String,Object?>.from(record)..remove('roster_hash')..remove('lease_expires');
    final response=await api.reconcile(const Uuid().v4(),[body]);
    final rows=response['results'];
    relayCheck(rows is List&&rows.length==1,'Invalid Relay acknowledgement.');
    final result=relayMap((rows as List).single);
    relayCheck(result['envelope_id']==queued.clientId,'Relay acknowledgement mismatch.');
    if(result['status']=='accepted'||result['status']=='duplicate'){
      relayCheck(result['source_ref'] is String,'Missing source acknowledgement.');
      // Remove only after M13 caller has acknowledged its own outbox.
      return result['source_ref'] as String;
    }
    if(result['status']=='expired'||result['status']=='retryable')return null;
    throw OrbitMessagingSecurityException('Relay authorization changed; review required.',409);
  }
  Future<Map<String,dynamic>?> checkpoint(String owner,String device,String clientId)=>
    _vault.get(owner,device,'out:'+clientId,now:DateTime.now().toUtc().millisecondsSinceEpoch~/1000);
  Future<void> clear(String owner,String device,String clientId)=>
    _vault.remove(owner,device,'out:'+clientId);
  /// Explicitly read own backend outcome page; never treat it as new
  /// authorization, a read acknowledgement or proof of peer plaintext.
  Future<Map<String,dynamic>> sync({String? cursor})=>api.sync(cursor:cursor);
}
).hasMatch(peerDigest),
      'Invalid Relay identity.');
    final source=relayMap(packet['source']);
    relayCheck(source['client_id']==client&&source['group_epoch']==lease.epoch,'Relay source mismatch.');
    final envelope=relayMap(packet['peer_envelope']);
    relayCheck(envelope['device_id']==device&&relayPeerDigest(thread.id,source,envelope,cap.frameBytes)==peerDigest,
      'Relay ciphertext mismatch.');
    relayCheck(await relayVerify('orbit-relay-sender-v1|$transcript|'+lease.id+'|$id|$digest|$peerDigest',
      packet['sender_proof'] as String,lease.senderKey),'Relay sender proof invalid.');
    final header=relayMap(jsonDecode(utf8.decode(base64Decode(envelope['protocol_header_b64'] as String))));
    relayCheck(header['v']==1&&header['type']=='olm'&&header['protocol']==orbitRelayMessageProtocol&&
      header['cid']==thread.id&&header['epoch']==lease.epoch&&header['kind']==source['kind']&&
      header['sender']==thread.peerId&&header['sender_device']==lease.sender&&
      header['sender_identity']==sender!.identity&&header['sender_curve']==sender.signedPrekey&&
      header['recipient_device']==device,'Relay encrypted scope mismatch.');
    final recordId='in:$id';
    final old=await _vault.get(owner,device,recordId,now:cap.clock.seconds);
    if(old!=null){
      relayCheck(old['digest']==digest&&old['peer_digest']==peerDigest&&old['lease_id']==lease.id&&
        old['source_client_id']==client,'Relay replay conflict.');
      _incomingLeases[recordId]=lease;
      return Map<String,Object?>.from(relayMap(old['receipt']));
    }
    final received=cap.clock.seconds;
    final receipt={'nonce':id,'received_at':received,'peer_digest':peerDigest,
      'signature_b64':await _sign(generation,relayReceiptInput(lease,id,client,digest,peerDigest,received))};
    await _current(generation);
    // Receipt attests durable encrypted device receipt, NOT successful
    // Olm decryption, read, source acceptance, or canonical history.
    await _vault.put(owner,device,recordId,{'lease_id':lease.id,'digest':digest,
      'source_client_id':client,'peer_digest':peerDigest,'source':source,'peer_envelope':envelope,'receipt':receipt},
      expiry:lease.expires+7*86400);
    await _current(generation);
    _incomingLeases[recordId]=lease;
    return receipt;
  }
  /// Decrypt only in this live lease session under the M13 owner crypto
  /// lock. Local previews are not canonical history or read receipts.
  Future<List<OrbitLocalDecryptedMessage>> incoming() async {
    final generation=_generation,cap=_cap,owner=_owner,device=_device,thread=_thread;
    if(cap==null||owner==null||device==null||thread==null||!active)return [];
    final results=<OrbitLocalDecryptedMessage>[];
    for(final entry in Map<String,OrbitRelayLease>.of(_incomingLeases).entries){
      await _current(generation);
      final lease=entry.value;
      if(!lease.live(cap))continue;
      final record=await _vault.get(owner,device,entry.key,now:cap.clock.seconds);
      if(record==null)continue;
      final source=relayMap(record['source']),peer=relayMap(record['peer_envelope']);
      final receipt=relayMap(record['receipt']);
      final client=record['source_client_id'] as String;
      final localId='local-relay-$client';
      final envelope=OrbitMailboxEnvelope(id:localId,messageId:localId,
        senderId:thread.peerId!,senderDeviceId:lease.sender,kind:source['kind'] as String,
        protocol:orbitRelayMessageProtocol,groupEpoch:lease.epoch,keyVersion:lease.claims['peer_key_version'] as int,
        ciphertextB64:peer['ciphertext_b64'] as String,headerB64:peer['protocol_header_b64'] as String,
        createdAt:DateTime.fromMillisecondsSinceEpoch((receipt['received_at'] as int)*1000,isUtc:true));
      try{
        final clear=await cipher.decryptRelayDirect(owner:owner,device:device,envelope:envelope,
          conversationId:thread.id,directory:_directories[thread.peerId]!);
        await _current(generation);
        results.add(OrbitLocalDecryptedMessage(id:localId,conversationId:thread.id,senderId:thread.peerId!,
          kind:envelope.kind,text:utf8.decode(clear),createdAt:envelope.createdAt));
      }catch(_){/* Durable ciphertext remains for ordinary authenticated sync. */}
    }
    results.sort((a,b)=>a.createdAt.compareTo(b.createdAt));return results;
  }
  /// Existing M13 outbox owns stable client ID and all device ciphertext.
  /// Relay stores only a receipt checkpoint; no fresh encryption or duplicate
  /// source IDs on retry. One recipient receipt per logical message.
  Future<bool> transfer(OrbitQueuedCiphertext queued) async {
    final generation=_generation,owner=_owner,device=_device,cap=_cap;
    if(owner==null||device==null||cap==null||!canUse(queued.conversationId,owner)||
       !orbitRelayKinds.contains(queued.kind)||queued.protocol!=orbitRelayMessageProtocol)return false;
    await _current(generation);
    final recordId='out:'+queued.clientId;
    if(await _vault.get(owner,device,recordId,now:cap.clock.seconds)!=null)return true;
    final source=Map<String,dynamic>.from(queued.toJson())..remove('conversation_id');
    final digest=relaySourceDigest(queued.conversationId,source,cap.frameBytes);
    for(final lease in _leases){
      if(!lease.live(cap)||queued.groupEpoch!=lease.epoch)continue;
      final matches=queued.envelopes.where((e)=>e.deviceId==lease.peer).toList();
      if(matches.length!=1)continue;
      final envelope=Map<String,dynamic>.from(matches.single.toJson());
      final pd=relayPeerDigest(lease.scope,source,envelope,cap.frameBytes);
      final packet=<String,Object?>{'lease':lease.token,'envelope_id':queued.clientId,
        'source_client_id':queued.clientId,'digest':digest,'peer_digest':pd,
        'source':Map<String,dynamic>.from(source)..remove('envelopes'),'peer_envelope':envelope};
      final proof=await _transport.transfer(lease,packet,(message)=>_sign(generation,message));
      if(proof==null)continue;
      final received=proof['received_at'];
      if(proof['nonce']!=queued.clientId||proof['peer_digest']!=pd||received is! int||
          received<lease.issued||received>=lease.expires||
          !await relayVerify(relayReceiptInput(lease,queued.clientId,queued.clientId,digest,pd,received),
            proof['signature_b64'] as String,lease.peerKey))continue;
      await _current(generation);
      await _vault.put(owner,device,recordId,{'lease_id':lease.id,'envelope_id':queued.clientId,
        'source_client_id':queued.clientId,'digest':digest,'source_envelope':source,'receipt':proof,
        'roster_hash':_rosterHash,'lease_expires':lease.expires},expiry:lease.expires+7*86400);
      return true;
    }
    return false;
  }
  Future<void> stop({bool revoke=false}) async {
    final old=List<OrbitRelayLease>.of(_leases);
    _generation++;_cap=null;_thread=null;_owner=null;_device=null;_rosterHash=null;
    _directories={};_keys={};_leases=[];_incomingLeases.clear();
    await _transport.stop();
    if(revoke){for(final lease in old){try{await api.revoke(lease.id,reason:'opt_out');}catch(_){}}}
  }
}

/// On reconnect, attempt source-authoritative reconciliation before ordinary
/// HTTPS. An expired or unavailable Relay lease never blocks the existing
/// messaging queue; the caller revalidates the current roster before fallback.
class OrbitRelayReconcile {
  OrbitRelayReconcile({required this.messaging,OrbitRelayVault? vault}):
    api=OrbitRelayApi(messaging:messaging),_vault=vault??OrbitRelayVault();
  final OrbitMessagingApi messaging;
  final OrbitRelayApi api;
  final OrbitRelayVault _vault;
  Future<String?> publish(OrbitQueuedCiphertext queued,String owner,String device,
      {required String currentRoster}) async {
    final id='out:'+queued.clientId;
    final record=await _vault.get(owner,device,id,now:DateTime.now().toUtc().millisecondsSinceEpoch~/1000);
    if(record==null)return null;
    relayCheck(record['roster_hash']==currentRoster,'Relay roster changed; review required.');
    final body=Map<String,Object?>.from(record)..remove('roster_hash')..remove('lease_expires');
    final response=await api.reconcile(const Uuid().v4(),[body]);
    final rows=response['results'];
    relayCheck(rows is List&&rows.length==1,'Invalid Relay acknowledgement.');
    final result=relayMap((rows as List).single);
    relayCheck(result['envelope_id']==queued.clientId,'Relay acknowledgement mismatch.');
    if(result['status']=='accepted'||result['status']=='duplicate'){
      relayCheck(result['source_ref'] is String,'Missing source acknowledgement.');
      // Remove only after M13 caller has acknowledged its own outbox.
      return result['source_ref'] as String;
    }
    if(result['status']=='expired'||result['status']=='retryable')return null;
    throw OrbitMessagingSecurityException('Relay authorization changed; review required.',409);
  }
  Future<Map<String,dynamic>?> checkpoint(String owner,String device,String clientId)=>
    _vault.get(owner,device,'out:'+clientId,now:DateTime.now().toUtc().millisecondsSinceEpoch~/1000);
  Future<void> clear(String owner,String device,String clientId)=>
    _vault.remove(owner,device,'out:'+clientId);
  /// Explicitly read own backend outcome page; never treat it as new
  /// authorization, a read acknowledgement or proof of peer plaintext.
  Future<Map<String,dynamic>> sync({String? cursor})=>api.sync(cursor:cursor);
}
