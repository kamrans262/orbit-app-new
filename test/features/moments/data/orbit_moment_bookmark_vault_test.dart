import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_outbox.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_bookmark_vault.dart';

class _MemoryVault implements OrbitMediaVault {
  final saved=<String,String>{};
  @override
  Future<String?> read(String key) async => saved[key];
  @override
  Future<void> write(String key,String value) async {saved[key]=value;}
  @override
  Future<void> delete(String key) async {saved.remove(key);}
}

void main(){
  test('Bookmarks store metadata only and are scoped to signed-in account',() async {
    var account='owner';
    final memory=_MemoryVault();
    final now=DateTime.now().toUtc();
    final vault=OrbitMomentBookmarkVault(vault:memory,owner:()async=>account);
    await vault.setSaved('moment-id','circle:c1',now,saved:true);
    final next=OrbitMomentBookmarkVault(vault:memory,owner:()async=>account);
    expect(await next.authorizedIds({'moment-id|circle:c1':now}),
      contains('moment-id|circle:c1'));
    expect(memory.saved.values.single,contains('moment-id|circle:c1'));
    expect(memory.saved.values.single,contains('"20'));
    account='someone-else';
    expect(await next.authorizedIds({'moment-id|circle:c1':now}),isEmpty);
    account='owner';
    await next.setSaved('moment-id','circle:c1',now,saved:false);
    expect(await vault.authorizedIds({'moment-id|circle:c1':now}),isEmpty);
  });

  test('An expired seven-day Moment cannot become an offline entitlement',() async {
    final now=DateTime.now().toUtc();
    final vault=OrbitMomentBookmarkVault(vault:_MemoryVault(),
      owner:()async=>'owner');
    await expectLater(vault.setSaved('expired','friends',
      now.subtract(const Duration(days:8)),saved:true),throwsStateError);
    await vault.setSaved('recent','friends',now,saved:true);
    expect(await vault.authorizedIds({'recent|friends':
      now.subtract(const Duration(days:8))}),isEmpty);
  });
}
