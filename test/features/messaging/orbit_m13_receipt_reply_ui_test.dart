import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_replies.dart';
import 'package:orbit_ui/features/messaging/presentation/orbit_message_visibility_observer.dart';

void main(){
  test('A reply target and quoted text exist only inside encrypted payload bytes',(){
    const value=OrbitEncryptedReply(targetId:'m123',text:'Hello Orbit');
    final body=jsonDecode(utf8.decode(value.encode())) as Map;
    expect(body['target_id'],'m123');
    expect(body['text'],'Hello Orbit');
    expect(OrbitEncryptedReply.fromText(utf8.decode(value.encode()))?.text,
      'Hello Orbit');
    expect(OrbitEncryptedReply.fromText('{}'),isNull);
    expect(()=>const OrbitEncryptedReply(
      targetId:'',text:'x').encode(),throwsFormatException);
    expect(()=>const OrbitEncryptedReply(
      targetId:'m',text:' ').encode(),throwsFormatException);
  });

  testWidgets('Read dwell callback is not triggered by a prefetched offscreen message',
      (tester) async{
    var seen=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      SingleChildScrollView(child:Column(children:[
        const SizedBox(height:1800),
        OrbitMessageVisibilityObserver(
          onDwell:()=>seen++,
          child:const SizedBox(width:150,height:60,child:Text('Private message'))),
      ])))));
    await tester.pump(const Duration(milliseconds:900));
    expect(seen,0);
    await tester.scrollUntilVisible(find.text('Private message'),250,
      scrollable:find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds:900));
    expect(seen,1);
    await tester.pump(const Duration(seconds:2));
    expect(seen,1);
  });
}
