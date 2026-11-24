import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_protocol.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_transport.dart';

class _TestDiscovery extends OrbitRelayDiscovery {
  List<RelayPeer> found=[];
  int? port;
  @override Future<void> start(int port) async {this.port=port;}
  @override Future<void> stop() async {port=null;}
  @override Future<List<RelayPeer>> peers() async=>found;
}
void main(){
  const scope='00000000-0000-4000-8000-000000000001';
  const sender='00000000-0000-4000-8000-000000000002';
  const receiver='00000000-0000-4000-8000-000000000003';
  const id='00000000-0000-4000-8000-000000000004';
  test('only local IPv4 routes may be used',(){
    expect(relayLocalAddress('192.168.1.5'),isTrue);
    expect(relayLocalAddress('172.16.2.3'),isTrue);
    expect(relayLocalAddress('8.8.8.8'),isFalse);
    expect(relayLocalAddress('127.0.0.1'),isFalse);
    expect(relayLocalAddress('example.test'),isFalse);
  });
  test('real TCP socket authenticates receiver before transmitting ciphertext',() async {
    final interfaces=await NetworkInterface.list(type:InternetAddressType.IPv4);
    final local=interfaces.expand((i)=>i.addresses).firstWhere((a)=>relayLocalAddress(a.address));
    final ed=Ed25519(),server=await ed.newKeyPair(),a=await ed.newKeyPair(),b=await ed.newKeyPair();
    final serverKey=await server.extractPublicKey(),aKey=await a.extractPublicKey(),bKey=await b.extractPublicKey();
    final kid=hashes.sha256.convert(serverKey.bytes).toString(),now=DateTime.now().toUtc(),seconds=now.millisecondsSinceEpoch~/1000;
    final cap=OrbitRelayCapabilities.fromJson({'enabled':true,'policy_revision':2,'server_time':now.toIso8601String(),
      'signing_key':{'id':kid,'public_ed25519':base64Encode(serverKey.bytes)},'limits':{'frame_bytes':32768,'lease_seconds':900},
      'protocol_versions':[orbitRelayProtocol],'content_types':['direct_message']});
    Future<OrbitRelayLease> lease(SimplePublicKey peer) async {
      final raw=jsonEncode({'v':1,'kid':kid,'lease_id':id,'sender_device':sender,'peer_device':receiver,'scope_ref':scope,
        'content_type':'direct_message','protocol_version':orbitRelayProtocol,'sender_key_version':1,'peer_key_version':1,
        'sender_ed25519':base64Encode(aKey.bytes),'peer_ed25519':base64Encode(peer.bytes),'source_epoch':1,
        'roster_hash':List.filled(64,'a').join(),'policy_revision':2,'issued_at':seconds,'expires_at':seconds+60});
      final signature=await ed.sign(utf8.encode('orbit-relay-lease-v1|'+raw),keyPair:server);
      return OrbitRelayLease.verify(base64Url.encode(utf8.encode(raw)).replaceAll('=','')+'.'+
        base64Url.encode(signature.bytes).replaceAll('=',''),cap,scope:scope,localDevice:sender,receiving:false);
    }
    Future<String> sign(KeyPair pair,String message) async=>base64Encode((await ed.sign(utf8.encode(message),keyPair:pair)).bytes);
    final aDiscovery=_TestDiscovery(),bDiscovery=_TestDiscovery();
    final source=OrbitRelayTransport(discovery:aDiscovery),target=OrbitRelayTransport(discovery:bDiscovery);
    var count=0;
    final packet=<String,Object?>{'envelope_id':id,'digest':List.filled(64,'b').join(),
      'peer_digest':List.filled(64,'c').join(),'opaque':'ciphertext'};
    try{
      await source.start(sign:(m)=>sign(a,m),accept:(_,__) async=>throw StateError('Unexpected inbound'));
      await target.start(sign:(m)=>sign(b,m),accept:(p,t) async {
        expect(p['opaque'],'ciphertext');
        expect(await relayVerify('orbit-relay-sender-v1|$t|$id|$id|'+(packet['digest'] as String)+'|'+(packet['peer_digest'] as String),
          p['sender_proof'] as String,base64Encode(aKey.bytes)),isTrue);
        count++;return {'verified':true};
      });
      aDiscovery.found=[(host:local.address,port:bDiscovery.port!)];
      // Wrong receiver key must never receive the packet.
      expect(await source.transfer(await lease(aKey),packet,(m)=>sign(a,m)),isNull);
      expect(count,0);
      expect(await source.transfer(await lease(bKey),packet,(m)=>sign(a,m)),{'verified':true});
      expect(count,1);
    }finally{await source.stop();await target.stop();}
    expect(source.running,isFalse);expect(target.running,isFalse);
  },timeout:const Timeout(Duration(seconds:40)));
}
