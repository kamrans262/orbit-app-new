import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_password_reset_flow.dart';
import 'package:orbit_ui/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/verify_otp_screen.dart';

void main() {
  Future<void> phone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('password recovery requests a recovery-only OTP, not an auth session',
      (tester) async {
    await phone(tester);
    var requests = 0;
    final client = OrbitIdentityClient(client: MockClient((request) async {
      requests++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/password/reset/request');
      expect(request.body, contains('member@example.test'));
      return http.Response(
          '{"message":"If the account exists, a password reset code has been sent."}', 202);
    }));
    await tester.pumpWidget(MaterialApp(home: OrbitPasswordResetFlow(
      identityClient: client, onCompleted: () {},
    )));
    await tester.enterText(find.byType(TextField).first, 'member@example.test');
    await tester.tap(find.byKey(ResetPasswordKeys.sendResetLinkButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(requests, 1);
    expect(find.byType(VerifyOtpScreen), findsOneWidget);
    expect(find.text('Enter the Code'), findsOneWidget);
    expect(find.textContaining('member@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery code goes to existing-style new password form, without issuing a session',
      (tester) async {
    await phone(tester);
    final client = OrbitIdentityClient(client: MockClient((_) async =>
        http.Response('{"message":"Code sent."}', 202)));
    await tester.pumpWidget(MaterialApp(home: OrbitPasswordResetFlow(
      identityClient: client, onCompleted: () {},
    )));
    await tester.enterText(find.byType(TextField).first, 'member@example.test');
    await tester.tap(find.byKey(ResetPasswordKeys.sendResetLinkButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byKey(const ValueKey<String>('otp_field_1')), '472819');
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byKey(VerifyOtpKeys.actionButton));
    await tester.pump();
    expect(find.text('Set New Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid recovery email stays on original Orbit form and shows validation',
      (tester) async {
    await phone(tester);
    var requests = 0;
    final client = OrbitIdentityClient(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 202);
    }));
    await tester.pumpWidget(MaterialApp(home: OrbitPasswordResetFlow(
      identityClient: client, onCompleted: () {},
    )));
    await tester.enterText(find.byType(TextField).first, 'bad');
    await tester.tap(find.byKey(ResetPasswordKeys.sendResetLinkButton));
    await tester.pump();
    expect(requests, 0);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.textContaining('Enter a valid email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('abandoned signup draft is removed before existing-account login', () {
    final identity = OrbitIdentityClient();
    identity.beginStandardSignup('Temporary Name', 'TemporaryPassword123');
    expect(identity.pendingSignupName, 'Temporary Name');
    identity.abandonStandardSignup();
    expect(identity.pendingSignupName, isNull);
  });
}
