import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('Welcome Log In opens Login screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    final loginButton = find.byKey(WelcomeKeys.logInButton);
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    expect(loginButton.hitTestable(), findsOneWidget);

    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
