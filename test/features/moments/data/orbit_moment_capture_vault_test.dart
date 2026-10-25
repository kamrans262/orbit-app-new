import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_outbox.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_capture_vault.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_audience_memory.dart';

class _MemoryVault implements OrbitMediaVault {
  final entries=<String,String>{};
  @override
  Future<String?> read(String key) async=>entries[key];
  @override
  Future<void> write(String key,String value) async {entries[key]=value;}
  @override
  Future<void> delete(String key) async {entries.remove(key);}
}

void main(){
  late Directory root;
  late _MemoryVault storage;
  var account='account-a';
  setUp(() async{
    root=await Directory.systemTemp.createTemp('orbit-m7-capture-');
    storage=_MemoryVault();
    account='account-a';
  });
  tearDown(() async{
    if(await root.exists())await root.delete(recursive:true);
  });
  OrbitMomentCaptureVault capture()=>OrbitMomentCaptureVault(
    vault:storage,owner:() async=>account,
    supportDirectory:()async=>root,
    temporaryDirectory:()async=>root);

  test('Captured photos are encrypted and restored for the same account',() async{
    final photo=Uint8List.fromList(List<int>.generate(200,(n)=>n%251));
    final first=capture();
    await first.savePhoto(photo);
    final folder=Directory('${root.path}/orbit-m7-encrypted-capture/account-a');
    final files=folder.listSync().whereType<File>().toList();
    expect(files,hasLength(1));
    expect(await files.single.readAsBytes(),isNot(equals(photo)));
    final second=capture();
    final recovered=await second.restore();
    expect(recovered?.kind,'image');
    expect(recovered?.photo,photo);
    account='account-b';
    expect(await capture().restore(),isNull);
    account='account-a';
    await second.clear();
    expect(await capture().restore(),isNull);
    expect(folder.listSync().whereType<File>(),isEmpty);
  });

  test('Encrypted voice draft survives restart without storing a plaintext copy',() async{
    final source=File('${root.path}/voice.m4a');
    final bytes=List<int>.generate(20000,(index)=>(index*19)%256);
    await source.writeAsBytes(bytes);
    await capture().saveClip(source,kind:'audio',durationMs:2000);
    await source.delete(); // The native camera has closed.
    final recovered=await capture().restore();
    expect(recovered?.kind,'audio');
    expect(recovered?.durationMs,2000);
    expect(await recovered!.clip!.readAsBytes(),bytes);
    await recovered.clip!.delete(); // Camera disposal clears transient plaintext.
    await capture().clear();
    expect(await capture().restore(),isNull);
  });

  test('Capture ciphertext tampering fails authentication and never opens',() async{
    await capture().savePhoto(Uint8List.fromList([1,2,3,4]));
    final dir=Directory('${root.path}/orbit-m7-encrypted-capture/account-a');
    final encrypted=dir.listSync().whereType<File>().single;
    await encrypted.writeAsBytes([9,9,9],flush:true);
    await expectLater(capture().restore(),throwsA(isA<Exception>()));
  });

  test('Previous audience is account-bound and never a publish authorization',() async{
    final memory=OrbitMomentAudienceMemory(vault:storage,owner:()async=>account);
    await memory.save('selected_friends',['friend-a','friend-a','friend-b']);
    final suggestion=await memory.read();
    expect(suggestion?.kind,'selected_friends');
    expect(suggestion?.targetIds,['friend-a','friend-b']);
    account='account-b';
    expect(await memory.read(),isNull);
    account='account-a';
    await memory.clear();
    expect(await memory.read(),isNull);
  });
}
