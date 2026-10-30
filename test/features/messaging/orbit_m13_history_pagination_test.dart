import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_cipher.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_coordinator.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_local_vault.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

OrbitMailboxEnvelope envelope(String id,int day) => OrbitMailboxEnvelope(
  id:'env-$id',messageId:id,senderId:'friend',senderDeviceId:'phone',
  kind:'text',protocol:'verified.test',groupEpoch:1,keyVersion:1,
  ciphertextB64:base64Encode(utf8.encode(id)),
  headerB64:base64Encode(utf8.encode('authenticated-header')),
  createdAt:DateTime.utc(2026,10,day),
);

class _Pages extends OrbitMessagingApi {
  int syncCount=0;
  String? olderCursor;
  final acknowledged=<String>[];

  @override
  Future<String> get owner async=>'owner';

  @override
  Future<OrbitMessagingCapabilities> capabilities() async=>
    const OrbitMessagingCapabilities(
      available:true,e2eeClientVerified:true,circleEnabled:true,
      realtimeAvailable:false,pushAvailable:false);

  @override
  Future<OrbitEnvelopePage> sync(String conversation,{
    List<String> delivered=const [],int limit=100}) async {
    syncCount++;
    return OrbitEnvelopePage([envelope('newest',30)],'cursor-older');
  }

  @override
  Future<OrbitEnvelopePage> envelopes(String conversation,{
    String? cursor,int limit=50}) async {
    olderCursor=cursor;
    return OrbitEnvelopePage([
      envelope('already-seen',29),envelope('oldest',28),
    ],null);
  }

  @override
  Future<void> delivered(String conversation,String id) async {
    acknowledged.add(id);
  }
}

class _DecryptForTest extends OrbitUnconfiguredMessagingCipher {
  _DecryptForTest();
  int decryptCount=0;

  @override
  bool get independentlyVerified=>true;

  @override
  Future<Uint8List> decrypt({
    required OrbitMailboxEnvelope envelope,
    required String conversationId,
  }) async {
    decryptCount++;
    // Force overlapping calls to exercise the cross-coordinator lock.
    await Future<void>.delayed(const Duration(milliseconds:10));
    return Uint8List.fromList(utf8.encode(envelope.messageId));
  }
}

class _MemoryVaultForTest extends OrbitMessagingLocalVault {
  final Map<String,OrbitLocalDecryptedMessage> saved={};

  @override
  Future<bool> hasMessage(String conversation,String messageId) async=>
    saved.containsKey(messageId);

  @override
  Future<void> saveDecrypted(OrbitLocalDecryptedMessage message) async {
    saved[message.id]=message;
  }

  @override
  Future<List<OrbitLocalDecryptedMessage>> history(String conversation,{
    int limit=50}) async {
    final rows=saved.values.where((m)=>m.conversationId==conversation).toList()
      ..sort((a,b)=>a.createdAt.compareTo(b.createdAt));
    return rows.length<=limit?rows:rows.sublist(rows.length-limit);
  }
}

void main(){
  test('Parallel pollers cannot decrypt the same mailbox envelope twice',() async {
    final api=_Pages();
    final vault=_MemoryVaultForTest();
    final cipher=_DecryptForTest();
    final a=OrbitMessagingCoordinator(api:api,cipher:cipher,vault:vault);
    final b=OrbitMessagingCoordinator(api:api,cipher:cipher,vault:vault);
    final thread=OrbitConversation(
      id:'same-thread',kind:'direct',groupEpoch:1,
      peerId:'friend',createdAt:DateTime.utc(2026,10,1));
    await Future.wait([
      a.refresh(thread,limit:2),
      b.refresh(thread,limit:2),
    ]);
    expect(cipher.decryptCount,1);
    expect(api.acknowledged,['env-newest']);
  });

  test('Initial HTTPS sync keeps its cursor across refresh and backfills only new ciphertext',() async {
    final api=_Pages();
    final vault=_MemoryVaultForTest();
    vault.saved['already-seen']=OrbitLocalDecryptedMessage(
      id:'already-seen',conversationId:'thread',senderId:'friend',
      kind:'text',text:'already-seen',createdAt:DateTime.utc(2026,10,29),
      envelopeId:'env-already-seen');
    final coordinator=OrbitMessagingCoordinator(
      api:api,cipher:_DecryptForTest(),vault:vault);
    final thread=OrbitConversation(
      id:'thread',kind:'direct',groupEpoch:1,
      peerId:'friend',createdAt:DateTime.utc(2026,10,1));

    await coordinator.refresh(thread,limit:2);
    await coordinator.refresh(thread,limit:2);
    expect(api.syncCount,2);
    expect(coordinator.hasOlderMessages('owner','thread'),isTrue);

    final older=await coordinator.loadOlder(thread,limit:2);
    expect(api.olderCursor,'cursor-older');
    expect(older.map((e)=>e.id),['oldest']);
    expect(coordinator.hasOlderMessages('owner','thread'),isFalse);
    expect(await coordinator.loadOlder(thread),isEmpty);
    expect(api.acknowledged,containsAll(['env-newest','env-oldest']));
    expect(api.acknowledged,hasLength(2));
  });
}
