import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/invite_people_screen.dart';

void main() {
  testWidgets('Invite People heading opens Login screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OrbitApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/invite-people');
    await tester.pumpAndSettle();

    expect(find.byType(InvitePeopleScreen), findsOneWidget);

    final shortcut = find.byKey(InvitePeopleKeys.loginShortcut);
    expect(shortcut, findsOneWidget);
    expect(shortcut.hitTestable(), findsOneWidget);

    await tester.tap(shortcut);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
