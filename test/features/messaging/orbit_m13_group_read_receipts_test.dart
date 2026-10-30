import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/group_chat/domain/models/group_chat_models.dart';
import 'package:orbit_ui/features/group_chat/presentation/screens/group_chat_screen.dart';

GroupChatMessage message({required bool mine})=>GroupChatMessage(
  id:mine?'own':'received',
  type:mine?GroupChatMessageType.sentText:GroupChatMessageType.receivedText,
  senderId:mine?'me':'friend',
  senderName:mine?'You':'Friend',
  isMine:mine,text:'An authorized Circle message',
  timestamp:'12:30',createdAt:DateTime.utc(2026,10,31),
  readRecipientNames:const ['Alice','Bob'],
  deliveredDevices:2,
);

Widget screen(GroupChatMessage entry)=>MaterialApp(home:GroupChatScreen(
  title:'Our Circle',participants:const [],memberCount:0,
  messages:[entry],currentUserId:'me',onBack:(){},
  onVideoCall:(){},liveMode:true,encryptedTransportReady:true,
));

void main(){
  testWidgets('Only my Circle bubbles display privacy-approved read recipients',
      (tester) async {
    await tester.pumpWidget(screen(message(mine:true)));
    await tester.pump();
    expect(find.text('Read by Alice, Bob'),findsOneWidget);

    await tester.pumpWidget(screen(message(mine:false)));
    await tester.pump();
    expect(find.text('Read by Alice, Bob'),findsNothing);
  });

  testWidgets('No recipient identities are displayed without opt-in receipts',
      (tester) async {
    final withoutRead=GroupChatMessage(
      id:'own',type:GroupChatMessageType.sentText,
      senderId:'me',senderName:'You',isMine:true,
      text:'Private message',timestamp:'12:30',
      createdAt:DateTime.utc(2026,10,31),deliveredDevices:2,
    );
    await tester.pumpWidget(screen(withoutRead));
    await tester.pump();
    expect(find.text('Delivered to 2 devices'),findsOneWidget);
    expect(find.textContaining('Read by'),findsNothing);
  });
}
