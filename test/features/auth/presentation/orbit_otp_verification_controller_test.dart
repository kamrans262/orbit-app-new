import 'package:flutter/material.dart';
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
