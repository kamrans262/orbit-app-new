import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/core/widgets/app_social_button.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';

void main() {
  Widget buildScreen({
    VoidCallback? onForgot,
    VoidCallback? onSignUp,
    void Function(String, String)? onLogIn,
  }) {
    return MaterialApp(
      home: LoginScreen(
        onLogIn: onLogIn ?? (_, __) {},
        onForgotPassword: onForgot ?? () {},
        onAppleLogin: () {},
        onGoogleLogin: () {},
        onSignUp: onSignUp ?? () {},
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Login card matches typography and shared component contract', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byKey(LoginKeys.card));
    final heading = tester.widget<Text>(find.byKey(LoginKeys.heading));
    final subtitle = tester.widget<Text>(find.byKey(LoginKeys.subtitle));

    expect(cardRect.left, closeTo(20, 0.01));
    expect(cardRect.right, closeTo(370, 0.01));
    expect(cardRect.center.dy, closeTo(422, 1.0));
    expect(heading.style?.fontFamily, 'Poppins');
    expect(heading.style?.fontSize, 24);
    expect(heading.style?.fontWeight, FontWeight.w700);
    expect(subtitle.style?.fontFamily, 'Poppins');
    expect(subtitle.style?.fontSize, 14);
    expect(find.byType(AppTextField), findsNWidgets(2));
    expect(find.byType(AppPrimaryButton), findsOneWidget);
    expect(find.byType(AppSocialButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility toggles immediately', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);

    await tester.tap(find.byKey(LoginKeys.passwordVisibility));
    await tester.pump();

    expect(tester.widget<TextField>(fields.at(1)).obscureText, isFalse);
  });

  testWidgets('Forgot Password and Sign Up expose independent callbacks', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    var forgotCount = 0;
    var signUpCount = 0;
    await tester.pumpWidget(
      buildScreen(onForgot: () => forgotCount++, onSignUp: () => signUpCount++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(LoginKeys.forgotPassword));
    await tester.pump();
    await tester.tap(find.byKey(LoginKeys.signUp));
    await tester.pump();

    expect(forgotCount, 1);
    expect(signUpCount, 1);
  });

  testWidgets('Login callback receives entered values', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    String? submittedEmail;
    String? submittedPassword;
    await tester.pumpWidget(
      buildScreen(
        onLogIn: (email, password) {
          submittedEmail = email;
          submittedPassword = password;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'emma@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.byKey(LoginKeys.loginButton));
    await tester.pump();

    expect(submittedEmail, 'emma@example.com');
    expect(submittedPassword, 'secret123');
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('Login remains scroll-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      await setPhoneSize(tester, size);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(LoginKeys.card), findsOneWidget);
      expect(find.byKey(LoginKeys.loginButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
