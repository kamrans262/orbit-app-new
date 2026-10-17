import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_invite_management_screen.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_setting_screen.dart';

void main() {
  testWidgets('Circle Setting summary opens Circle Invite management', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: CircleSettingScreen.demo()));
    await tester.pumpAndSettle();

    final entry = find.byKey(CircleSettingKeys.inviteManagementEntry);
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byKey(CircleInviteManagementKeys.title), findsOneWidget);
    expect(find.text('Circle Invite management'), findsOneWidget);
  });
}
