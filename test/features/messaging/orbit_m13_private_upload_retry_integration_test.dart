import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_ui/features/media/data/orbit_media_crypto.dart';
import 'package:orbit_ui/features/media/data/orbit_media_repository.dart';

class _VerifiedPrivateUploadApi extends OrbitMediaRepository {
  _VerifiedPrivateUploadApi(http.Client client):super(client:client);
  @override
  Future<Map<String,dynamic>> control(String method,String path,{
      Map<String,Object?>? body,String? idempotencyKey}) async{
    if(method=='POST'&&path=='/media/uploads'){
      return {
        'media_id':'4ec493c1-d21a-4eea-a09e-91566cbd5936',
        'upload_id':'upload-one','state':'initiated',
        'storage_mode':'multipart','part_size_bytes':OrbitMediaFormat.partBytes,
      };
    }
    if(method=='GET'&&path=='/media/uploads/upload-one'){
      return {'state':'uploading','uploaded_parts':<Object>[]};
    }
    if(method=='POST'&&path=='/media/uploads/upload-one/parts'){
      final checksum=body!['checksum_sha256'] as String;
      expect(body['part_number'],1);
      expect(body['content_length'],3);
      return {'url':'https://private.example.invalid/cipherpart',
        'required_headers':{
          'content-length':'3',
          'x-amz-checksum-sha256':base64Encode(
            List<int>.generate(32,(i)=>int.parse(checksum.substring(i*2,i*2+2),radix:16))),
        }};
    }
    if(method=='POST'&&path=='/media/uploads/upload-one/complete'){
      expect(body!['parts'],[{'part_number':1,'etag':'verified-cipher-tag'}]);
      return {'state':'ready'};
    }
    throw StateError('Unexpected private transfer operation');
  }
}

/// Simulates a new process reusing a previously uploaded ciphertext part.
class _ResumedPrivateUploadApi extends OrbitMediaRepository {
  _ResumedPrivateUploadApi(http.Client client):super(client:client);
  @override
  Future<Map<String,dynamic>> control(String method,String path,{
    Map<String,Object?>? body,String? idempotencyKey,
  }) async {
    if(method=='POST' && path=='/media/uploads') {
      return {
        'media_id':'4ec493c1-d21a-4eea-a09e-91566cbd5936',
        'upload_id':'resume-upload','state':'uploading',
        'storage_mode':'multipart',
        'part_size_bytes':OrbitMediaFormat.partBytes,
      };
    }
    if(method=='GET' && path=='/media/uploads/resume-upload') {
      return {'state':'uploading','uploaded_parts':[
        {'part_number':1,'etag':'already-verified-ciphertext'}
      ]};
    }
    if(method=='POST' && path=='/media/uploads/resume-upload/complete') {
      expect(body?['parts'],[
        {'part_number':1,'etag':'already-verified-ciphertext'},
      ]);
      return {'state':'ready'};
    }
    throw StateError('Unexpected resume transfer request: $method $path');
  }
}

void main(){
  test('Temporary storage 503 retries the same encrypted multipart data',() async {
    var sent=0;
    final httpClient=MockClient((request) async{
      sent++;
      expect(request.method,'PUT');
      expect(request.url.scheme,'https');
      expect(request.url.host,'private.example.invalid');
      expect(request.bodyBytes,[12,24,36]);
      return sent==1
        ?http.Response('',503)
        :http.Response('',200,headers:{'etag':'verified-cipher-tag'});
    });
    final temp=await Directory.systemTemp.createTemp('orbit_cipherpart_test_');
    try{
      final path=File('${temp.path}/encrypted.bin');
      await path.writeAsBytes([12,24,36],flush:true);
      final sealed=OrbitSealedMedia(
        file:path,key:Uint8List(32),noncePrefix:Uint8List(8),
        plainBytes:3,bytes:3,sha256:digest.sha256.convert(
          [12,24,36]).toString(),ownerId:'owner-test',
        transferId:'4ec493c1-d21a-4eea-a09e-91566cbd5936',
        purpose:'message',variant:'original');
      final repository=_VerifiedPrivateUploadApi(httpClient);
      final receipt=await repository.upload(sealed,
        kind:'image',mime:'image/jpeg');
      expect(receipt.ready,isTrue);
      expect(sent,2);
    }finally{
      httpClient.close();
      if(await temp.exists())await temp.delete(recursive:true);
    }
  });
  test('Resume reuses confirmed ciphertext part without reuploading bytes',() async {
    var unexpectedPuts=0;
    final client=MockClient((request) async {
      unexpectedPuts++;
      return http.Response('must not PUT a confirmed part',500);
    });
    final temp=await Directory.systemTemp.createTemp('orbit_resume_test_');
    try {
      final file=File('${temp.path}/sealed.cipher');
      await file.writeAsBytes([12,24,36],flush:true);
      final sealed=OrbitSealedMedia(
        file:file,key:Uint8List(32),noncePrefix:Uint8List(8),
        plainBytes:3,bytes:3,
        sha256:digest.sha256.convert([12,24,36]).toString(),
        ownerId:'owner',transferId:'4ec493c1-d21a-4eea-a09e-91566cbd5936',
        purpose:'message',variant:'original');
      final receipt=await _ResumedPrivateUploadApi(client).upload(
        sealed,kind:'image',mime:'image/jpeg');
      expect(receipt.ready,isTrue);
      expect(unexpectedPuts,0);
    }finally{
      client.close();
      if(await temp.exists())await temp.delete(recursive:true);
    }
  });

}
