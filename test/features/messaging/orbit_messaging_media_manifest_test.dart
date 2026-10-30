import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/chat/chat_media_image.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_media_bridge.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

void main(){
  const id='4ec493c1-d21a-4eea-a09e-91566cbd5936';
  test('Encrypted media manifest contains no URL, local path or media key',(){
    const image=OrbitEncryptedChatMedia(
      mediaId:id,kind:'image',mime:'image/jpeg',durationMs:null);
    final data=image.encode();
    expect(data,contains(id));
    expect(data, isNot(contains('cipher_key')));
    expect(data, isNot(contains('https://')));
    expect(data, isNot(contains('/storage/')));
    final decoded=OrbitEncryptedChatMedia.tryParse(data);
    expect(decoded?.kind,'image');
    expect(decoded?.mediaId,id);
    expect(OrbitEncryptedChatMedia.tryParse('{"media_id":"bad"}'),isNull);
    expect(OrbitEncryptedChatMedia.tryParse('{"v":1,"type":"orbit_m13_media","kind":"file","mime":"text/plain","media_id":"'+id+'"}'),isNull);
    expect(OrbitEncryptedChatMedia.tryParse('Just regular chat text'),isNull);
  });

  test('Encrypted private-media ID can travel only inside a device envelope',(){
    const item=OrbitCipherEnvelope(deviceId:id,ciphertextB64:'opaque',
      headerB64:'signed');
    final body=item.toJson();
    expect(body.keys,containsAll(['device_id','ciphertext_b64','protocol_header_b64']));
    expect(body.keys, isNot(contains('media_id')));
    expect(body.keys, isNot(contains('local_path')));
  });

  testWidgets('Original media image accepts decrypted bytes without a file or URL',
      (tester) async {
    final bytes=Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/d3sAAAAASUVORK5CYII='));
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:ChatMediaImage(source:'',bytes:bytes,width:100,height:100))));
    await tester.pumpAndSettle();
    expect(find.byType(Image),findsOneWidget);
    final visual=tester.widget<Image>(find.byType(Image));
    expect(visual.image,isA<MemoryImage>());
  });
}
