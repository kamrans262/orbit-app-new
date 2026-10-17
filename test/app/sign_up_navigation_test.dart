import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/sign_up_screen.dart';

void main() {
  testWidgets('Login Sign Up opens Sign Up and Log In returns to Login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    final welcomeLogin = find.text('Log In');
    await tester.ensureVisible(welcomeLogin);
    expect(welcomeLogin.hitTestable(), findsOneWidget);
    await tester.tap(welcomeLogin);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final signUp = find.byKey(LoginKeys.signUp);
    await tester.ensureVisible(signUp);
    expect(signUp.hitTestable(), findsOneWidget);
    await tester.tap(signUp);
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    final logIn = find.byKey(SignUpKeys.logIn);
    await tester.ensureVisible(logIn);
    expect(logIn.hitTestable(), findsOneWidget);
    await tester.tap(logIn);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
