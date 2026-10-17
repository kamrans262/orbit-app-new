import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_card.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_header.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> expectTopGap(
    WidgetTester tester,
    Widget screen,
    Key cardKey,
    Key headingKey,
  ) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byKey(cardKey));
    final headingRect = tester.getRect(find.byKey(headingKey));
    expect(headingRect.top - cardRect.top, closeTo(AuthCard.topPadding, 0.01));
    expect(find.byType(AuthHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Login heading starts exactly 36px from card top', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await expectTopGap(
      tester,
      LoginScreen(
        onLogIn: (_, _) {},
        onForgotPassword: () {},
        onAppleLogin: () {},
        onGoogleLogin: () {},
        onSignUp: () {},
      ),
      LoginKeys.card,
      LoginKeys.heading,
    );
  });

  testWidgets('Sign Up heading starts exactly 36px from card top', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await expectTopGap(
      tester,
      SignUpScreen(
        onSignUp: (_, _, _) {},
        onAppleSignUp: () {},
        onGoogleSignUp: () {},
        onLogIn: () {},
      ),
      SignUpKeys.card,
      SignUpKeys.heading,
    );
  });

  testWidgets('Reset Password heading starts exactly 36px from card top', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await expectTopGap(
      tester,
      ResetPasswordScreen(onSendResetLink: (_) {}),
      ResetPasswordKeys.card,
      ResetPasswordKeys.heading,
    );
  });
}
