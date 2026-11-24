import 'dart:convert';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_protocol.dart';

void main(){
  const scope='00000000-0000-4000-8000-000000000001';
  const sender='00000000-0000-4000-8000-000000000002';
  const peer='00000000-0000-4000-8000-000000000003';
  const id='00000000-0000-4000-8000-000000000004';
  test('lease verifies exact signed bytes and rejects wrong peer and tamper',() async {
    final ed=Ed25519(),pair=await ed.newKeyPair(),key=await pair.extractPublicKey();
    final kid=hashes.sha256.convert(key.bytes).toString();
    final now=DateTime.now().toUtc(),seconds=now.millisecondsSinceEpoch~/1000;
    final cap=OrbitRelayCapabilities.fromJson({'enabled':true,'policy_revision':2,'server_time':now.toIso8601String(),
      'signing_key':{'id':kid,'public_ed25519':base64Encode(key.bytes)},'limits':{'frame_bytes':32768,'lease_seconds':900},
      'protocol_versions':[orbitRelayProtocol],'content_types':['direct_message']});
    final claims={'v':1,'kid':kid,'lease_id':id,'sender_device':sender,'peer_device':peer,'scope_ref':scope,
      'content_type':'direct_message','protocol_version':orbitRelayProtocol,'sender_key_version':1,'peer_key_version':1,
      'sender_ed25519':base64Encode(key.bytes),'peer_ed25519':base64Encode(key.bytes),'source_epoch':1,
      'roster_hash':List.filled(64,'a').join(),'policy_revision':2,'issued_at':seconds,'expires_at':seconds+60};
    final raw=jsonEncode(claims);
    final sig=await ed.sign(utf8.encode('orbit-relay-lease-v1|'+raw),keyPair:pair);
    final token=base64Url.encode(utf8.encode(raw)).replaceAll('=','')+'.'+base64Url.encode(sig.bytes).replaceAll('=','');
    expect((await OrbitRelayLease.verify(token,cap,scope:scope,localDevice:peer,receiving:true)).id,id);
    await expectLater(OrbitRelayLease.verify(token,cap,scope:scope,localDevice:sender,receiving:true),throwsFormatException);
    final tampered=base64Url.encode(utf8.encode(raw.replaceFirst('"policy_revision":2','"policy_revision":3'))).replaceAll('=','')+'.'+token.split('.')[1];
    await expectLater(OrbitRelayLease.verify(tampered,cap,scope:scope,localDevice:peer,receiving:true),throwsFormatException);
  });
  test('source digest sorts device IDs and rejects duplicate recipients',(){
    Map<String,dynamic> envelope(String device)=>{'device_id':device,'ciphertext_b64':base64Encode(List.filled(32,1)),
      'protocol_header_b64':base64Encode(List.filled(12,2))};
    final source=<String,dynamic>{'client_id':id,'kind':'text','protocol':orbitRelayMessageProtocol,'group_epoch':1,
      'envelopes':[envelope(peer),envelope(sender)]};
    final digest=relaySourceDigest(scope,source,32768);
    source['envelopes']=[envelope(sender),envelope(peer)];
    expect(relaySourceDigest(scope,source,32768),digest);
    source['envelopes']=[envelope(peer),envelope(peer)];
    expect(()=>relaySourceDigest(scope,source,32768),throwsFormatException);
  });
}
