import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('Forgot Password opens Reset Password from Login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    final logIn = find.byKey(WelcomeKeys.logInButton);
    await tester.ensureVisible(logIn);
    expect(logIn.hitTestable(), findsOneWidget);
    await tester.tap(logIn);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final forgotPassword = find.byKey(LoginKeys.forgotPassword);
    await tester.ensureVisible(forgotPassword);
    expect(forgotPassword.hitTestable(), findsOneWidget);
    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
