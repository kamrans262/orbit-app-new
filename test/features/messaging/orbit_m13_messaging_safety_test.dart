import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_ui/features/circles/domain/models/friend_details_models.dart';
import 'package:orbit_ui/features/direct_chat/domain/models/direct_chat_models.dart';
import 'package:orbit_ui/features/direct_chat/presentation/screens/direct_chat_screen.dart';
import 'package:orbit_ui/features/direct_chat/presentation/widgets/direct_chat_input_bar.dart';
import 'package:orbit_ui/features/group_chat/presentation/screens/group_chat_screen.dart';
import 'package:orbit_ui/features/group_chat/presentation/widgets/chat_input_bar.dart';
import 'package:orbit_ui/features/messages/presentation/screens/messages_screen.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_cipher.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_coordinator.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

void main(){
  test('Default E2EE boundary blocks all send and cryptographic setup',() async {
    final c=OrbitMessagingCoordinator();
    expect(c.cipher.independentlyVerified,isFalse);
    await expectLater(c.requireSecure(),
      throwsA(isA<OrbitMessagingSecurityException>()));
    await expectLater(c.sendText(OrbitConversation(
      id:'thread',kind:'direct',groupEpoch:1,
      peerId:'peer',createdAt:DateTime.utc(2026)), 'secret'),
      throwsA(isA<OrbitMessagingSecurityException>()));
    await expectLater(c.cipher.setupDevice(),
      throwsA(isA<OrbitMessagingSecurityException>()));
  });

  test('Remote envelope JSON carries ciphertext but never message plaintext',(){
    final record=OrbitMailboxEnvelope.fromJson({
      'id':'e','message_id':'m','sender_id':'alice',
      'sender_device_id':'phone','kind':'text','protocol':'ratchet.v1',
      'group_epoch':1,'recipient_key_version':1,
      'ciphertext_b64':'ZmFrZS1lbmNyeXB0ZWQ=',
      'protocol_header_b64':'ZmFrZS1oZWFkZXI=',
      'created_at':'2026-10-30T00:00:00Z',
    });
    expect(record.senderId,'alice');
    final envelope=OrbitCipherEnvelope(deviceId:'bob',
      ciphertextB64:record.ciphertextB64,headerB64:record.headerB64);
    expect(envelope.toJson().keys,
      containsAll(['device_id','ciphertext_b64','protocol_header_b64']));
    expect(envelope.toJson().containsKey('text'),isFalse);
    expect(OrbitMessagingCapabilities.fromJson({
      'available':true,'e2ee_client_verified':false,
      'circle_enabled':true,'realtime_available':false,
      'push_available':false,
    }).e2eeClientVerified,isFalse);
  });

  testWidgets('Authenticated direct chat does not show demo location or enable unverified send',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:DirectChatScreen(
      person:const DirectChatPerson(id:'u',name:'Friend',
        statusText:'Secure messaging pending',isOnline:false),
      messages:const [],liveMode:true,encryptedTransportReady:false,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(DirectChatScreenKeys.liveLocationCard),findsNothing);
    final field=tester.widget<TextField>(
      find.byKey(DirectChatInputKeys.field));
    expect(field.enabled,isFalse);
    expect(find.textContaining('Verified encryption'),findsOneWidget);
    expect(find.text('South Beach'),findsNothing);
  });

  testWidgets('Authenticated Circle chat never offers unencrypted input',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:GroupChatScreen(
      title:'Our Circle',participants:const [],memberCount:0,
      messages:const [],liveMode:true,encryptedTransportReady:false,
      onBack:(){},onVideoCall:(){},
    )));
    await tester.pumpAndSettle();
    final field=tester.widget<TextField>(find.byKey(ChatInputKeys.textField));
    expect(field.enabled,isFalse);
    expect(find.textContaining('verified end-to-end encryption'),findsOneWidget);
  });

  testWidgets('Existing Messages row opens live callback instead of demo thread',
      (tester) async {
    var opened=0;
    await tester.pumpWidget(MaterialApp(home:MessagesScreen(
      friends:const [FriendMemberData(id:'person',name:'Current Friend',
        status:'Private',imagePath:null)],
      onOpenFriend:(friend)=>opened++,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MessagesKeys.row('person')));
    await tester.pumpAndSettle();
    expect(opened,1);
    expect(find.text('Current Friend'),findsOneWidget);
    expect(find.byKey(DirectChatScreenKeys.title),findsNothing);
  });
}
