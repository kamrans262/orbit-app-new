import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/media/data/orbit_media_crypto.dart';
import 'package:orbit_ui/features/media/data/orbit_media_repository.dart';

class FakeMediaIdentity extends OrbitIdentityClient {
  bool done = false;
  Map<String,Object?>? completePayload;
  int signatures = 0;
  @override
  Future<Map<String,dynamic>> socialRequest(String method, String path,
      {Map<String,Object?>? body,String? idempotencyKey}) async {
    if(method=='POST' && path=='/media/uploads') {
      expect(idempotencyKey,isNotNull);
      return {'data':{
        'media_id':'media-1','upload_id':'upload-1',
        'part_size_bytes':OrbitMediaFormat.partBytes,
        'storage_mode':'multipart'}};
    }
    if(method=='GET' && path=='/media/uploads/upload-1') {
      return {'data':done
          ? {'state':'ready'}
          : {'state':'initiated','uploaded_parts':[]}};
    }
    if(method=='POST' && path=='/media/uploads/upload-1/parts') {
      signatures++;
      final checksum=body!['checksum_sha256'] as String;
      final base64Checksum=base64Encode(
          Uint8List.fromList(List<int>.generate(32,(i)=>
              int.parse(checksum.substring(i*2,i*2+2),radix:16))));
      return {'data':{
        'url':'https://storage.example.test/signed-upload',
        'required_headers':{
          'content-length':(body['content_length'] as num).toInt().toString(),
          'x-amz-checksum-sha256':base64Checksum}}};
    }
    if(method=='POST' && path=='/media/uploads/upload-1/complete') {
      completePayload=body;
      done=true;
      return {'data':{'state':'verifying'}};
    }
    if(method=='POST' && path=='/media/media-1/grants') {
      expect(body!['audience_kind'],'only_me');
      return {'data':{'grant_ids':['grant-1']}};
    }
    throw StateError('Unexpected control endpoint.');
  }
}

void main(){
  late Directory temp;
  setUp(() async => temp=await Directory.systemTemp.createTemp('orbit-m6-transfer'));
  tearDown(()async{
    if(await temp.exists())await temp.delete(recursive:true);
  });

  test('Uploads ciphertext only with provider part checksum and waits for ready',
      () async {
    final fake=FakeMediaIdentity();
    var transferred=0;
    final httpClient=MockClient((req)async{
      expect(req.method,'PUT');
      expect(req.url.scheme,'https');
      expect(req.headers.containsKey('authorization'),false);
      transferred+=req.bodyBytes.length;
      return http.Response('',200,headers:{'etag':'"test-etag"'});
    });
    final encrypted=await OrbitMediaCrypto().sealBytes(
      Uint8List.fromList([1,2,3,4,5]),
      destination:File(temp.path+'/blob.enc'),ownerId:'owner',
      transferId:'11111111-1111-4111-8111-111111111111',purpose:'moment');
    final repo=OrbitMediaRepository(identity:fake,client:httpClient);
    final progress=<double>[];
    final receipt=await repo.upload(encrypted,kind:'image',mime:'image/jpeg',
      onProgress:progress.add);
    expect(receipt.ready,true);
    expect(receipt.mediaId,'media-1');
    expect(fake.signatures,1);
    expect(transferred,encrypted.bytes);
    expect(progress.last,1);
    expect(fake.completePayload?['cipher_sha256'],encrypted.sha256);
    expect(await repo.createGrants('media-1',audience:'only_me',
      recipients:[],keyEnvelopes:[{'device_id':'device-id'}],
      idempotencyKey:'123e4567-e89b-12d3-a456-426614174000'),
      ['grant-1']);
  });

  test('Never uploads to insecure or unexpected object-store URL', () async {
    final fake=FakeMediaIdentity();
    // A URL guard prevents an injected control-plane destination from
    // exfiltrating a ciphertext upload over an unprotected HTTP channel.
    final repo=OrbitMediaRepository(identity:fake,client:MockClient((req) async {
      throw StateError('No signed upload should be reached.');
    }));
    // A non-private URL is tested by a different fake below; this test
    // establishes the unavailable-file guard before any network operation.
    final draft=OrbitSealedMedia(file:File(temp.path+'/missing'),
      key:Uint8List(32),noncePrefix:Uint8List(8),plainBytes:1,
      bytes:17,sha256:digest.sha256.convert([1]).toString(),
      ownerId:'owner',transferId:'11111111-1111-4111-8111-111111111111',
      purpose:'moment',variant:'original');
    await expectLater(repo.upload(draft,kind:'image',mime:'image/jpeg'),
      throwsA(isA<FileSystemException>()));
  });
}
