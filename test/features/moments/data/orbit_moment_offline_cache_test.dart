import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_outbox.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_offline_cache.dart';

class _MemoryVault implements OrbitMediaVault {
  final Map<String,String> values=<String,String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key,String value) async {values[key]=value;}
  @override
  Future<void> delete(String key) async {values.remove(key);}
}

void main(){
  test('M7 offline preview is encrypted, account-scoped and purgeable',() async {
    final root=await Directory.systemTemp.createTemp('orbit-m7-offline-test-');
    addTearDown(()=>root.delete(recursive:true));
    final vault=_MemoryVault();
    var owner='11111111-1111-4111-8111-111111111111';
    final cache=OrbitMomentOfflineCache(
      vault:vault,owner:() async=>owner,
      directory:() async=>root,
    );
    final now=DateTime.now().toUtc();
    final jpeg=Uint8List.fromList([0xff,0xd8,1,2,3,4,0xff,0xd9]);
    await cache.save(
      id:'22222222-2222-4222-8222-222222222222',
      mediaId:'33333333-3333-4333-8333-333333333333',
      creatorId:owner,contextId:'self',audienceRevision:1,
      publishedAt:now.subtract(const Duration(minutes:1)),
      issuedAt:now,expiresAt:now.add(const Duration(minutes:3)),
      viewExpiresAt:now.add(const Duration(days:6)),preview:jpeg,
    );
    final files=await root.list(recursive:true).where((e)=>
      e is File && e.path.endsWith('.cipher')).toList();
    final content=files.single as File;
    final ciphertext=await content.readAsBytes();
    expect(ciphertext, isNot(orderedEquals(jpeg)));
    final restored=await cache.read();
    expect(restored,isNotEmpty);
    expect(restored.single.bytes,orderedEquals(jpeg));
    owner='44444444-4444-4444-8444-444444444444';
    expect(await cache.read(),isEmpty);
    owner='11111111-1111-4111-8111-111111111111';
    await cache.purge(owner);
    expect(await cache.read(),isEmpty);
    expect(await content.exists(),isFalse);
  });

  test('M7 read cache rejects overlong or expired server leases',() async {
    final root=await Directory.systemTemp.createTemp('orbit-m7-cache-bounds-');
    addTearDown(()=>root.delete(recursive:true));
    final vault=_MemoryVault();
    final owner='11111111-1111-4111-8111-111111111111';
    final cache=OrbitMomentOfflineCache(vault:vault,
      owner:() async=>owner,directory:() async=>root);
    final now=DateTime.now().toUtc();
    Future<void> invalid(Duration ttl)=>cache.save(
      id:'22222222-2222-4222-8222-222222222222',
      mediaId:'33333333-3333-4333-8333-333333333333',
      creatorId:owner,contextId:'self',audienceRevision:1,
      publishedAt:now.subtract(const Duration(minutes:1)),
      issuedAt:now,expiresAt:now.add(ttl),
      viewExpiresAt:now.add(const Duration(days:6)),
      preview:Uint8List.fromList([1,2,3]),
    );
    await expectLater(invalid(const Duration(minutes:15)),throwsFormatException);
    await expectLater(invalid(const Duration(minutes:-1)),throwsFormatException);
    expect(await cache.read(),isEmpty);
  });
}
