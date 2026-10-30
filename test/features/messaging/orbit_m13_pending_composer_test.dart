import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_ui/features/direct_chat/domain/models/direct_chat_models.dart';
import 'package:orbit_ui/features/direct_chat/presentation/screens/direct_chat_screen.dart';
import 'package:orbit_ui/features/direct_chat/presentation/widgets/direct_chat_input_bar.dart';
import 'package:orbit_ui/features/group_chat/presentation/screens/group_chat_screen.dart';
import 'package:orbit_ui/features/group_chat/presentation/widgets/chat_input_bar.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

void main(){
  testWidgets('Direct live composer shows queued ciphertext Waiting, not delivered',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:DirectChatScreen(
      person:const DirectChatPerson(
        id:'peer',name:'Friend',statusText:'Private',isOnline:false),
      messages:const [],liveMode:true,encryptedTransportReady:true,
      onSendMessage:(_ ) async {
        throw const OrbitQueuedMessageException('stable-id');
      },
    )));
    await tester.enterText(find.byKey(DirectChatInputKeys.field),'Hello');
    await tester.pump();
    await tester.tap(find.byKey(DirectChatInputKeys.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:400));
    expect(find.byKey(DirectChatScreenKeys.message('local-stable-id')),
      findsOneWidget);
    expect(find.text('Waiting'),findsOneWidget);
    expect(tester.widget<TextField>(
      find.byKey(DirectChatInputKeys.field)).controller?.text,isEmpty);
  });

  testWidgets('Circle live composer retains waiting message without read receipt',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:GroupChatScreen(
      title:'Our Circle',participants:const [],memberCount:0,
      messages:const [],onBack:(){},onVideoCall:(){},
      liveMode:true,encryptedTransportReady:true,
      onSendMessage:(_ ) async {
        throw const OrbitQueuedMessageException('circle-queue');
      },
    )));
    await tester.enterText(find.byKey(ChatInputKeys.textField),'Hello Circle');
    await tester.pump();
    await tester.tap(find.byKey(ChatInputKeys.sendButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:400));
    expect(find.byKey(GroupChatScreenKeys.message('local-circle-queue')),
      findsOneWidget);
    expect(find.text('Waiting for connection'),findsOneWidget);
    expect(find.textContaining('Read by'),findsNothing);
  });
}
