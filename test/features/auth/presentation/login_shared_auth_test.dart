import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_account_switch.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_card.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_divider.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_social_buttons.dart';

void main() {
  testWidgets('Login reuses the shared authentication components', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onLogIn: (_, _) {},
          onForgotPassword: () {},
          onAppleLogin: () {},
          onGoogleLogin: () {},
          onSignUp: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.byType(AuthDivider), findsOneWidget);
    expect(find.byType(AuthSocialButtons), findsOneWidget);
    expect(find.byType(AuthAccountSwitch), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
