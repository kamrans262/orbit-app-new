import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_otp_verification_controller.dart';
import 'package:orbit_ui/features/auth/presentation/screens/verify_otp_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/sign_up_screen.dart';

void main() {
  testWidgets('Login and Sign Up have no duplicate code-choice actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: LoginScreen(
      onLogIn: (_, _) {},
      onForgotPassword: () {},
      onAppleLogin: () {},
      onGoogleLogin: () {},
      onSignUp: () {},
    )));
    await tester.pump();
    expect(find.byKey(LoginKeys.loginButton), findsOneWidget);
    expect(find.text('Continue with a code'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: SignUpScreen(
      onSignUp: (_, _, _) {},
      onAppleSignUp: () {},
      onGoogleSignUp: () {},
      onLogIn: () {},
    )));
    await tester.pump();
    expect(find.byKey(SignUpKeys.signUpButton), findsOneWidget);
    expect(find.text('Sign up with a code'), findsNothing);
  });

  testWidgets('OTP API request uses existing six-digit verification screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    final client = OrbitIdentityClient(client: MockClient((request) async {
      requests++;
      expect(request.url.path, '/api/v1/auth/otp/request');
      expect(request.method, 'POST');
      expect(request.body, contains('member@example.test'));
      expect(request.body, contains('"purpose":"signup"'));
      return http.Response('{"message":"Verification sent."}', 202);
    }));
    await tester.pumpWidget(MaterialApp(home: OrbitOtpVerificationController(
      recipient: 'member@example.test',
      identityClient: client,
      onVerified: () {},
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(requests, 1);
    expect(find.byType(VerifyOtpScreen), findsOneWidget);
    expect(find.byKey(VerifyOtpKeys.otpInput), findsOneWidget);
    expect(find.text('Enter the Code'), findsOneWidget);
    expect(find.textContaining('member@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Already-dispatched OTP opens the approved screen without a second request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    final client = OrbitIdentityClient(client: MockClient((_) async {
      requests++;
      return http.Response('{"message":"unexpected duplicate request"}', 503);
    }));
    await tester.pumpWidget(MaterialApp(home: OrbitOtpVerificationController(
      recipient: 'member@example.test',
      identityClient: client,
      codeAlreadySent: true,
      onVerified: () {},
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(requests, 0);
    expect(find.byType(VerifyOtpScreen), findsOneWidget);
    expect(find.byKey(VerifyOtpKeys.otpInput), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login rejection stays on Login and prevents repeat taps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final result = Completer<String?>();
    var checks = 0;
    var navigations = 0;
    await tester.pumpWidget(MaterialApp(home: LoginScreen(
      preflight: (_, __) {
        checks++;
        return result.future;
      },
      onLogIn: (_, __) => navigations++,
      onForgotPassword: () {},
      onAppleLogin: () {},
      onGoogleLogin: () {},
      onSignUp: () {},
    )));
    await tester.enterText(find.byType(TextField).at(0), 'existing@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'WrongPassword123');
    await tester.tap(find.byKey(LoginKeys.loginButton));
    await tester.pump();
    expect(checks, 1);
    expect(navigations, 0);
    expect(find.byType(LoginScreen), findsOneWidget);
    result.complete('Invalid credentials.');
    await tester.pump();
    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(navigations, 0);
  });

  testWidgets('Sign Up duplicate stays on Sign Up without reaching OTP',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var navigations = 0;
    var requests = 0;
    await tester.pumpWidget(MaterialApp(home: SignUpScreen(
      preflight: (_, __, ___) async {
        requests++;
        return 'An account already exists. Please log in instead.';
      },
      onSignUp: (_, __, ___) => navigations++,
      onAppleSignUp: () {},
      onGoogleSignUp: () {},
      onLogIn: () {},
    )));
    await tester.enterText(find.byType(TextField).at(0), 'Existing User');
    await tester.enterText(find.byType(TextField).at(1), 'existing@example.test');
    await tester.enterText(find.byType(TextField).at(2), 'StrongPassword123');
    await tester.tap(find.byKey(SignUpKeys.signUpButton));
    await tester.pump();
    expect(requests, 1);
    expect(navigations, 0);
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('An account already exists. Please log in instead.'),
        findsOneWidget);
  });

  testWidgets('Valid preflight continues exactly once to existing OTP navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var continuations = 0;
    await tester.pumpWidget(MaterialApp(home: LoginScreen(
      preflight: (_, __) async => null,
      onLogIn: (_, __) => continuations++,
      onForgotPassword: () {},
      onAppleLogin: () {},
      onGoogleLogin: () {},
      onSignUp: () {},
    )));
    await tester.enterText(find.byType(TextField).at(0), 'existing@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'CorrectPassword123');
    await tester.tap(find.byKey(LoginKeys.loginButton));
    await tester.pump();
    expect(continuations, 1);
  });

  testWidgets('Failed OTP delivery remains on original screen and offers retry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = OrbitIdentityClient(client: MockClient((_) async =>
        http.Response('{"message":"Verification service unavailable."}', 503)));
    await tester.pumpWidget(MaterialApp(home: OrbitOtpVerificationController(
      recipient: 'member@example.test',
      identityClient: client,
      onVerified: () {},
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(VerifyOtpScreen), findsOneWidget);
    expect(find.text('Verification service unavailable.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
