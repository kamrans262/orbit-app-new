import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_outbox.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_intent_vault.dart';

class _MemoryVault implements OrbitMediaVault {
  final data=<String,String>{};
  @override
  Future<String?> read(String key) async=>data[key];
  @override
  Future<void> write(String key,String value) async {data[key]=value;}
  @override
  Future<void> delete(String key) async {data.remove(key);}
}

void main(){
  test('M7 publishing intent survives repository recreation without storing photo bytes',() async {
    const owner='account-a';
    var active=owner;
    final storage=_MemoryVault();
    final first=OrbitMomentIntentVault(vault:storage,owner:()async=>active);
    final created=DateTime.utc(2026,10,25,7);
    final item=OrbitStoredMomentIntent(
      owner:owner,transfer:'transfer-01',clientId:'client-uuid',
      audienceKind:'selected_friends',targetIds:const ['friend-1'],
      caption:'Encrypted vault draft',createdAt:created);
    await first.save(item);
    final recreated=OrbitMomentIntentVault(vault:storage,owner:()async=>active);
    final drafts=await recreated.pending(owner);
    expect(drafts,hasLength(1));
    expect(drafts.single.clientId,item.clientId);
    expect(drafts.single.caption,item.caption);
    expect(drafts.single.targetIds,['friend-1']);
    expect(storage.data.keys.any((x)=>x.contains('photoBytes')),isFalse);
    active='account-b';
    await expectLater(recreated.pending(owner),throwsStateError);
    active=owner;
    await recreated.remove(owner,item.transfer);
    expect(await first.pending(owner),isEmpty);
  });
  test('M7 signout/account switch purges secure publish metadata before auth is cleared',() async {
    const previous='previous-account';
    var current=previous;
    final vaultStore=_MemoryVault();
    final vault=OrbitMomentIntentVault(
      vault:vaultStore,owner:() async=>current);
    await vault.save(OrbitStoredMomentIntent(
      owner:previous,transfer:'transfer-1',clientId:'publish-uuid-1',
      audienceKind:'only_me',targetIds:const [],caption:'private caption',
      createdAt:DateTime.now().toUtc()));
    expect((await vault.pending(previous)),hasLength(1));
    current='new-account';
    await vault.purge(previous);
    expect(vaultStore.data.keys.where((key)=>key.contains(previous)),isEmpty);
    current=previous;
    expect(await vault.pending(previous),isEmpty);
  });

  test('M7 rejects reassigning one encrypted transfer to a different publish request',() async {
    const owner='owner';
    final vault=OrbitMomentIntentVault(vault:_MemoryVault(),
      owner:()async=>owner);
    final now=DateTime.utc(2026,10,25);
    await vault.save(OrbitStoredMomentIntent(
      owner:owner,transfer:'transfer-1',clientId:'client-a',
      audienceKind:'only_me',targetIds:const [],caption:'',
      createdAt:now));
    await expectLater(vault.save(OrbitStoredMomentIntent(
      owner:owner,transfer:'transfer-1',clientId:'client-b',
      audienceKind:'only_me',targetIds:const [],caption:'',
      createdAt:now)),throwsStateError);
  });
  test('M7 encrypted draft backoff persists after restart without losing consent',() async {
    const owner='owner';
    final storage=_MemoryVault();
    final vault=OrbitMomentIntentVault(vault:storage,owner:() async=>owner);
    const transfer='transfer-backoff';
    await vault.save(OrbitStoredMomentIntent(
      owner:owner,transfer:transfer,clientId:'one-client',
      audienceKind:'selected_friends',targetIds:const ['friend'],
      caption:'saved',placeLabel:'Consented place',
      locationConsent:true,taggedUserIds:const ['friend'],
      createdAt:DateTime.now().toUtc()));
    final before=DateTime.now().toUtc();
    final first=await vault.markAttempt(owner,transfer);
    expect(first.attemptCount,1);
    expect(first.retryAfter!.isAfter(before),isTrue);
    final afterRestart=OrbitMomentIntentVault(vault:storage,owner:()async=>owner);
    final persisted=(await afterRestart.pending(owner)).single;
    expect(persisted.attemptCount,1);
    expect(persisted.locationConsent,isTrue);
    expect(persisted.placeLabel,'Consented place');
    expect(persisted.taggedUserIds,['friend']);
    final second=await afterRestart.markAttempt(owner,transfer);
    expect(second.attemptCount,2);
    expect(second.retryAfter!.isAfter(first.retryAfter!),isTrue);
  });

}
