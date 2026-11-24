import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_local_vault.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_protocol.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_session.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_vault.dart';

const scope='00000000-0000-4000-8000-000000000001';
const device='00000000-0000-4000-8000-000000000002';
const client='00000000-0000-4000-8000-000000000003';
const lease='00000000-0000-4000-8000-000000000004';

class _MemoryVault extends OrbitRelayVault {
  Map<String,dynamic>? record;
  @override
  Future<Map<String,dynamic>?> get(String owner,String device,String id,{required int now}) async=>record;
  @override
  Future<void> remove(String owner,String device,String id) async{record=null;}
}
class _Api extends OrbitMessagingApi {
  int syncs=0,posts=0,checks=0;
  bool historical=false,published=false,failSync=false;
  String state='accepted';
  Map<String,Object?>? lastBody;
  @override Future<String> get owner async=>'alice';
  @override Future<bool> wasPublished(String conversation,String clientId) async {
    checks++;expect(conversation,scope);expect(clientId,client);return published;
  }
  @override Future<Map<String,dynamic>> request(String method,String path,{Map<String,Object?>? body}) async {
    if(path.startsWith('/relay/sync')){
      syncs++;
      if(failSync)throw OrbitIdentityException('unavailable',503);
      if(historical&&syncs.isOdd)return {'items':[],'next_cursor':'next'};
      return {'items':historical?[{'envelope_id':client,'source_client_id':client,'status':'accepted'}]:[],'next_cursor':null};
    }
    expect(method,'POST');expect(path,'/relay/reconcile');
    posts++;lastBody=body;
    return {'results':[{'envelope_id':client,'status':state,'source_ref':state=='accepted'||state=='duplicate'?scope:null}]};
  }
}
OrbitQueuedCiphertext packet()=>OrbitQueuedCiphertext(clientId:client,conversationId:scope,
  kind:'text',protocol:orbitRelayMessageProtocol,groupEpoch:1,envelopes:[
    OrbitCipherEnvelope(deviceId:device,ciphertextB64:base64Encode(List.filled(32,1)),
      headerB64:base64Encode(List.filled(12,2))),
  ]);
Map<String,dynamic> checkpoint(OrbitQueuedCiphertext p){
  final source=Map<String,dynamic>.from(p.toJson())..remove('conversation_id');
  return {'lease_id':lease,'envelope_id':client,'source_client_id':client,
    'digest':relaySourceDigest(scope,source,32768),'source_envelope':source,
    'roster_hash':'roster','lease_expires':100,'peer_user':'bob'};
}
void main(){
  test('durable attempt without receipt reconciles same ID and exact ciphertext',() async {
    final p=packet(),v=_MemoryVault()..record=checkpoint(p),api=_Api();
    final r=OrbitRelayReconcile(messaging:api,vault:v);
    expect(await r.publish(p,'alice',device,currentRoster:'roster'),scope);
    final body=(api.lastBody!['items'] as List).single as Map;
    expect(body['source_client_id'],client);expect(body['lease_id'],lease);
    expect(body.containsKey('receipt'),isFalse);expect(body.containsKey('peer_user'),isFalse);
    expect(v.record,isNotNull);await r.clear('alice',device,client);expect(v.record,isNull);
  });
  test('historical pagination must be confirmed by fresh M13 source receipt',() async {
    final p=packet(),v=_MemoryVault()..record=checkpoint(p),api=_Api()..historical=true;
    final r=OrbitRelayReconcile(messaging:api,vault:v);
    expect(await r.publish(p,'alice',device,currentRoster:'roster'),scope);
    expect(api.syncs,2);expect(api.checks,1);expect(api.posts,1);
    api.published=true;
    expect(await r.publish(p,'alice',device,currentRoster:'roster'),client);
    expect(api.posts,1);
  });
  test('expired Relay allows fallback; rejected or modified source does not',() async {
    final p=packet(),v=_MemoryVault()..record=checkpoint(p),api=_Api()..state='expired'..failSync=true;
    final r=OrbitRelayReconcile(messaging:api,vault:v);
    expect(await r.publish(p,'alice',device,currentRoster:'roster'),isNull);
    api.state='rejected';
    await expectLater(r.publish(p,'alice',device,currentRoster:'roster'),throwsA(isA<OrbitMessagingSecurityException>()));
    final count=api.posts;
    await expectLater(r.publish(p,'alice',device,currentRoster:'different'),throwsFormatException);
    v.record!['digest']='tampered';
    await expectLater(r.publish(p,'alice',device,currentRoster:'roster'),throwsFormatException);
    expect(api.posts,count);
  });
}
