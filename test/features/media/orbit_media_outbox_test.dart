import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_crypto.dart';
import 'package:orbit_ui/features/media/data/orbit_media_outbox.dart';

class InMemoryMediaVault implements OrbitMediaVault {
  final Map<String,String> values={};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key,String value) async {values[key]=value;}
  @override
  Future<void> delete(String key) async {values.remove(key);}
}

void main() {
  late Directory temp;
  late InMemoryMediaVault vault;
  String? currentOwner;
  late OrbitMediaOutbox outbox;
  setUp(() async {
    temp=await Directory.systemTemp.createTemp('orbit-m6-outbox');
    vault=InMemoryMediaVault();
    currentOwner='owner-a';
    outbox=OrbitMediaOutbox(vault:vault,
      signedInOwner:()async=>currentOwner,
      supportDirectory:()async=>temp);
  });
  tearDown(() async {
    if(await temp.exists()) await temp.delete(recursive:true);
  });

  test('Ciphertext-only offline outbox resumes with verified content key', () async {
    final sealed=await OrbitMediaCrypto().sealBytes(Uint8List.fromList([4,5,6]),
      destination:File(temp.path+'/draft.enc'),ownerId:'owner-a',
      transferId:'11111111-1111-4111-8111-111111111111',purpose:'moment');
    final item=await outbox.enqueue(sealed,kind:'image',mime:'image/jpeg');
    final raw=vault.values.values.join();
    expect(raw, isNot(contains('plainBytes=[4, 5, 6]')));
    expect((await outbox.pending('owner-a')),hasLength(1));
    final resumed=await outbox.restore(item);
    expect(resumed.sha256,sealed.sha256);
    expect(resumed.key,sealed.key);
    final c=await resumed.file.readAsBytes();
    expect(c, isNot(orderedEquals([4,5,6])));
    await outbox.discard(item);
    expect((await outbox.pending('owner-a')),isEmpty);
    expect(await resumed.file.exists(),isFalse);
  });

  test('A second account cannot read encrypted files or content keys', () async {
    final sealed=await OrbitMediaCrypto().sealBytes(Uint8List.fromList([9]),
      destination:File(temp.path+'/draft2.enc'),ownerId:'owner-a',
      transferId:'22222222-2222-4222-8222-222222222222',purpose:'moment');
    final item=await outbox.enqueue(sealed,kind:'image',mime:'image/jpeg');
    currentOwner='owner-b';
    await expectLater(outbox.pending('owner-a'),throwsStateError);
    await expectLater(outbox.restore(item),throwsStateError);
    await expectLater(outbox.discard(item),throwsStateError);
    expect(await outbox.pending('owner-b'),isEmpty);
  });

  test('Tampered queued ciphertext is not replayed', () async {
    final sealed=await OrbitMediaCrypto().sealBytes(Uint8List.fromList([7]),
      destination:File(temp.path+'/draft3.enc'),ownerId:'owner-a',
      transferId:'33333333-3333-4333-8333-333333333333',purpose:'moment');
    final item=await outbox.enqueue(sealed,kind:'image',mime:'image/jpeg');
    final restored=await outbox.restore(item);
    final changed=await restored.file.readAsBytes();
    changed[0]^=1;
    await restored.file.writeAsBytes(changed);
    await expectLater(outbox.restore(item),throwsStateError);
  });

  test('Owner-specific purge clears encrypted bytes and OS vault entries', () async {
    final sealed=await OrbitMediaCrypto().sealBytes(Uint8List.fromList([1]),
      destination:File(temp.path+'/draft4.enc'),ownerId:'owner-a',
      transferId:'44444444-4444-4444-8444-444444444444',purpose:'moment');
    final item=await outbox.enqueue(sealed,kind:'image',mime:'image/jpeg');
    final saved=await outbox.restore(item);
    await outbox.purge('owner-a');
    expect(await saved.file.exists(),isFalse);
    expect(vault.values,isEmpty);
  });
}
