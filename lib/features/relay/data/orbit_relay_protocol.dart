import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

const orbitRelayProtocol='orbit-relay-direct-v1';
const orbitRelayMessageProtocol='orbit-m13-olm-megolm-v1';
const orbitRelayKinds={'text','emoji','sticker','reaction','reply'};
final _uuid=RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
final _hex=RegExp(r'^[0-9a-f]{64}$');
void relayCheck(bool condition,String message){if(!condition)throw FormatException(message);}
Map<String,dynamic> relayMap(Object? raw){
  relayCheck(raw is Map,'Invalid Relay object.');
  return Map<String,dynamic>.from(raw as Map);
}
bool relayUuid(String value)=>_uuid.hasMatch(value);
String relayHash(Object? value)=>hashes.sha256.convert(utf8.encode(jsonEncode(value))).toString();
String relayNonce()=>List.generate(32,(_)=>Random.secure().nextInt(256).toRadixString(16).padLeft(2,'0')).join();
List<int> relayBytes(String value,int length){
  final bytes=base64Decode(value);
  relayCheck(bytes.length==length&&base64Encode(bytes)==value,'Invalid Relay binary.');
  return bytes;
}
Future<bool> relayVerify(String message,String signature,String publicKey) async {
  try{return await Ed25519().verify(utf8.encode(message),signature:Signature(
    relayBytes(signature,64),publicKey:SimplePublicKey(relayBytes(publicKey,32),type:KeyPairType.ed25519)));
  }catch(_){return false;}
}
/// Monotonic clock anchored by authenticated server time. Never restore a
/// lease clock across process restart or extend it using device wall time.
class OrbitRelayClock {
  OrbitRelayClock(DateTime serverTime):_seconds=serverTime.toUtc().millisecondsSinceEpoch~/1000 {
    _watch.start();
  }
  final int _seconds;
  final Stopwatch _watch=Stopwatch();
  int get seconds=>_seconds+_watch.elapsedMilliseconds~/1000;
}
class OrbitRelayCapabilities {
  OrbitRelayCapabilities.fromJson(Map<String,dynamic> j):
    enabled=j['enabled']==true,revision=j['policy_revision'] as int,
    clock=OrbitRelayClock(DateTime.parse(j['server_time'] as String)),
    keyId=(j['signing_key'] as Map?)?['id'] as String?,
    publicKey=(j['signing_key'] as Map?)?['public_ed25519'] as String?,
    frameBytes=((j['limits'] as Map)['frame_bytes'] as int).clamp(1024,32768).toInt(),
    leaseSeconds=((j['limits'] as Map)['lease_seconds'] as int).clamp(60,900).toInt(),
    protocolAllowed=(j['protocol_versions'] as List).contains(orbitRelayProtocol)&&
      (j['content_types'] as List).contains('direct_message');
  final bool enabled,protocolAllowed;
  final int revision,frameBytes,leaseSeconds;
  final String? keyId,publicKey;
  final OrbitRelayClock clock;
  bool get ready=>enabled&&protocolAllowed&&keyId!=null&&publicKey!=null;
}
class OrbitRelayLease {
  OrbitRelayLease._(this.token,this.claims);
  final String token;
  final Map<String,dynamic> claims;
  String get id=>claims['lease_id'] as String;
  String get scope=>claims['scope_ref'] as String;
  String get sender=>claims['sender_device'] as String;
  String get peer=>claims['peer_device'] as String;
  String get senderKey=>claims['sender_ed25519'] as String;
  String get peerKey=>claims['peer_ed25519'] as String;
  int get expires=>claims['expires_at'] as int;
  int get issued=>claims['issued_at'] as int;
  int get epoch=>claims['source_epoch'] as int;
  bool live(OrbitRelayCapabilities cap)=>cap.ready&&claims['kid']==cap.keyId&&
    claims['policy_revision']==cap.revision&&cap.clock.seconds+2>=issued&&cap.clock.seconds+2<expires;
  static Future<OrbitRelayLease> verify(String token,OrbitRelayCapabilities cap,
      {required String scope,required String localDevice,required bool receiving}) async {
    relayCheck(cap.ready&&token.length<=4096,'Relay is unavailable.');
    final parts=token.split('.');
    relayCheck(parts.length==2,'Invalid lease.');
    final raw=base64Url.decode(base64Url.normalize(parts[0]));
    final signature=base64Url.decode(base64Url.normalize(parts[1]));
    final key=relayBytes(cap.publicKey!,32);
    relayCheck(hashes.sha256.convert(key).toString()==cap.keyId,'Server key mismatch.');
    final json=utf8.decode(raw);
    relayCheck(await Ed25519().verify(utf8.encode('orbit-relay-lease-v1|'+json),
      signature:Signature(signature,publicKey:SimplePublicKey(key,type:KeyPairType.ed25519))),
      'Lease signature invalid.');
    final j=relayMap(jsonDecode(json));
    for(final name in ['lease_id','sender_device','peer_device','scope_ref']){
      relayCheck(j[name] is String&&_uuid.hasMatch(j[name] as String),'Invalid lease scope.');
    }
    relayCheck(j['v']==1&&j['protocol_version']==orbitRelayProtocol&&j['content_type']=='direct_message'&&
      j['scope_ref']==scope&&j['sender_device']!=j['peer_device']&&
      j[receiving?'peer_device':'sender_device']==localDevice&&
      j['roster_hash'] is String&&_hex.hasMatch(j['roster_hash'] as String)&&
      j['source_epoch'] is int&&j['sender_key_version'] is int&&j['peer_key_version'] is int&&
      (j['source_epoch'] as int)>0&&(j['sender_key_version'] as int)>0&&(j['peer_key_version'] as int)>0,
      'Lease scope or device mismatch.');
    relayBytes(j['sender_ed25519'] as String,32);relayBytes(j['peer_ed25519'] as String,32);
    final lease=OrbitRelayLease._(token,Map.unmodifiable(j));
    relayCheck(lease.live(cap)&&lease.expires-lease.issued<=cap.leaseSeconds&&lease.expires>lease.issued,
      'Lease expired or policy changed.');
    return lease;
  }
}
Map<String,Object?> relayCanonicalEnvelope(Map<String,dynamic> envelope,int frameBytes){
  relayCheck(envelope.length==3&&envelope['device_id'] is String&&
    _uuid.hasMatch(envelope['device_id'] as String),'Invalid Relay envelope.');
  final cipher=envelope['ciphertext_b64'] as String;
  final header=envelope['protocol_header_b64'] as String;
  final bytes=base64Decode(cipher),head=base64Decode(header);
  relayCheck(bytes.length>=16&&bytes.length<=frameBytes&&head.length>=12&&head.length<=4096&&
    base64Encode(bytes)==cipher&&base64Encode(head)==header,'Invalid Relay frame.');
  return {'device_id':envelope['device_id'],'ciphertext_b64':cipher,'protocol_header_b64':header};
}
List<Object?> relaySourcePrefix(String scope,Map<String,dynamic> source){
  relayCheck(source['client_id'] is String&&_uuid.hasMatch(source['client_id'] as String)&&
    orbitRelayKinds.contains(source['kind'])&&source['protocol']==orbitRelayMessageProtocol&&
    source['group_epoch'] is int&&(source['group_epoch'] as int)>0,'Unsupported Relay source.');
  return [scope,source['client_id'],source['kind'],source['protocol'],source['group_epoch']];
}
String relaySourceDigest(String scope,Map<String,dynamic> source,int frameBytes){
  final prefix=relaySourcePrefix(scope,source);
  final raw=source['envelopes'] as List;
  relayCheck(raw.isNotEmpty&&raw.length<=12,'Invalid device roster.');
  final envelopes=raw.map((e)=>relayCanonicalEnvelope(relayMap(e),frameBytes)).toList()
    ..sort((a,b)=>(a['device_id'] as String).compareTo(b['device_id'] as String));
  relayCheck(envelopes.map((e)=>e['device_id']).toSet().length==envelopes.length,'Duplicate device.');
  return relayHash([...prefix,envelopes]);
}
String relayPeerDigest(String scope,Map<String,dynamic> source,
    Map<String,dynamic> envelope,int frameBytes)=>
    relayHash([...relaySourcePrefix(scope,source),relayCanonicalEnvelope(envelope,frameBytes)]);
String relayReceiptInput(OrbitRelayLease lease,String envelopeId,String clientId,String digest,
    String peerDigest,int receivedAt)=>[
  'orbit-relay-receipt-v1',lease.id,lease.scope,lease.sender,lease.peer,envelopeId,clientId,
  digest,peerDigest,'received',envelopeId,receivedAt.toString(),
].join('|');


/// Exact encrypted packet identity, independent of the server-generated
/// mailbox UUID. The same ciphertext must never advance an Olm ratchet twice.
String relayMailboxFingerprint(String scope,String sender,String senderDevice,
    String kind,int epoch,String cipher,String header)=>relayHash([
  'orbit-relay-mailbox-v1',scope,sender,senderDevice,kind,epoch,cipher,header,
]);
