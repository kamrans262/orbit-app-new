import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/chat/message_reactions.dart';

void main(){
  testWidgets('Long-press keeps six original reactions and offers message options',
      (tester) async {
    var pressed=0;
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:Center(child:MessageReactionRegion(
        messageId:'server-acknowledged-id',
        isMine:true,
        onMessageOptions:()=>pressed++,
        child:const Text('Private encrypted chat text'),
      ))),
    ));
    await tester.longPress(find.text('Private encrypted chat text'));
    await tester.pumpAndSettle();
    expect(find.text('Message options'),findsOneWidget);
    expect(find.byType(MessageReactionPicker),findsOneWidget);
    await tester.tap(find.text('Message options'));
    await tester.pumpAndSettle();
    expect(pressed,1);
    expect(find.byType(MessageReactionPicker),findsNothing);
  });

  testWidgets('Unmodified original reaction picker has no options control',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home:Scaffold(body:Center(child:MessageReactionRegion(
        messageId:'original-message',isMine:false,
        child:Text('Another private message'),
      ))),
    ));
    await tester.longPress(find.text('Another private message'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageReactionPicker),findsOneWidget);
    expect(find.text('Message options'),findsNothing);
  });
}
