import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/presentation/screens/friend_details_screen.dart';
import 'package:orbit_ui/features/group_chat/presentation/screens/group_chat_screen.dart';

void main() {
  testWidgets('Friend Details Group card opens the matching Group Chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendDetailsScreen.demo(onBack: () {}, onAddMember: () {}),
      ),
    );

    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();

    final firstGroup = find.byKey(FriendDetailsKeys.group('basketball'));
    expect(firstGroup, findsOneWidget);
    await tester.ensureVisible(firstGroup);
    await tester.tap(firstGroup);
    await tester.pumpAndSettle();

    expect(find.byType(GroupChatScreen), findsOneWidget);
    expect(find.text('Basketball squad'), findsOneWidget);
  });
}
