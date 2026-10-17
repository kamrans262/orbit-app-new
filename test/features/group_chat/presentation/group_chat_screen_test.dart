import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/group_chat/presentation/screens/group_chat_screen.dart';
import 'package:orbit_ui/features/group_chat/presentation/widgets/chat_input_bar.dart';
import 'package:orbit_ui/features/group_chat/presentation/widgets/group_chat_header.dart';

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size, {
  GroupChatScreen? screen,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: screen ?? GroupChatScreen.demo()));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Group chat remains overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        await _pumpAtSize(tester, size);

        expect(find.byKey(GroupChatHeaderKeys.title), findsOneWidget);
        expect(find.byKey(GroupChatScreenKeys.messageList), findsOneWidget);
        expect(find.byKey(ChatInputKeys.textField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('composer sends a local message and keeps controls reachable', (
    tester,
  ) async {
    await _pumpAtSize(tester, const Size(390, 844));

    final field = find.byKey(ChatInputKeys.textField);
    expect(field.hitTestable(), findsOneWidget);
    await tester.tap(field);
    await tester.enterText(field, 'New backend-ready message');
    await tester.pump();

    final send = find.byKey(ChatInputKeys.sendButton);
    expect(send.hitTestable(), findsOneWidget);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('New backend-ready message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long content and missing assets do not overflow', (
    tester,
  ) async {
    await _pumpAtSize(tester, const Size(320, 568));

    // Group chat initially auto-scrolls to the newest message. Verify the
    // earlier message after scrolling backwards rather than assuming it is
    // built and visible at the initial viewport.
    final messageList = find.byKey(GroupChatScreenKeys.messageList);
    await tester.drag(messageList, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(GroupChatScreenKeys.message('received-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
