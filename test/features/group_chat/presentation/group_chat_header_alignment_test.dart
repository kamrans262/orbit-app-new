import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/group_chat/presentation/screens/group_chat_screen.dart';
import 'package:orbit_ui/features/group_chat/presentation/widgets/group_chat_header.dart';

void main() {
  testWidgets('avatars stay left and online/member status stays right', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: GroupChatScreen.demo(memberCount: 6)),
    );
    await tester.pumpAndSettle();

    final avatars = find.byKey(GroupChatHeaderKeys.participantAvatars);
    final online = find.byKey(GroupChatHeaderKeys.onlineStatus);
    final count = find.byKey(GroupChatHeaderKeys.memberCount);

    expect(avatars, findsOneWidget);
    expect(online, findsOneWidget);
    expect(count, findsOneWidget);
    expect(find.text('6 People'), findsOneWidget);

    final avatarRect = tester.getRect(avatars);
    final onlineRect = tester.getRect(online);
    final countRect = tester.getRect(count);

    expect(avatarRect.center.dx, lessThan(onlineRect.center.dx));
    expect(avatarRect.center.dx, lessThan(countRect.center.dx));
    expect(onlineRect.right, greaterThan(300));
    expect(countRect.right, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
