import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_otp_input.dart';
import 'package:orbit_ui/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/verify_otp_screen.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_card.dart';

void main() {
  Widget buildScreen({ValueChanged<String>? onVerify}) {
    return MaterialApp(
      home: VerifyOtpScreen(
        recipient: '+123 45886 576',
        onVerifyCode: onVerify ?? (_) {},
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('OTP screen reuses AuthCard and exact heading/subtitle spacing', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.byType(AppOtpInput), findsOneWidget);
    expect(find.text('Enter the Code'), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to\n+123 45886 576'),
      findsOneWidget,
    );

    final cardRect = tester.getRect(find.byKey(VerifyOtpKeys.card));
    final headingRect = tester.getRect(find.byKey(VerifyOtpKeys.heading));
    final subtitleRect = tester.getRect(find.byKey(VerifyOtpKeys.subtitle));
    final otpRect = tester.getRect(find.byKey(VerifyOtpKeys.otpInput));

    expect(headingRect.top - cardRect.top, closeTo(36, 0.01));
    expect(subtitleRect.top - headingRect.bottom, closeTo(5, 0.01));
    expect(otpRect.top - subtitleRect.bottom, closeTo(20, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP action aligns vertically with Reset Password action', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: ResetPasswordScreen(onSendResetLink: (_) {})),
    );
    await tester.pump();
    final resetButtonTop = tester
        .getRect(find.byKey(ResetPasswordKeys.sendResetLinkButton))
        .top;

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    final otpButtonTop = tester
        .getRect(find.byKey(VerifyOtpKeys.actionButton))
        .top;

    expect(otpButtonTop, closeTo(resetButtonTop, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown is dynamic and button enables after six digits', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    String? submitted;
    await tester.pumpWidget(
      buildScreen(onVerify: (value) => submitted = value),
    );
    await tester.pump();

    expect(find.text('Send Code (00:23)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Send Code (00:22)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('otp_field_1')),
      '123456',
    );
    await tester.pump();

    expect(find.text('Verify Code'), findsOneWidget);
    final action = find.byKey(VerifyOtpKeys.actionButton);
    await tester.ensureVisible(action);
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    await tester.pump();

    expect(submitted, '123456');
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('OTP remains scroll-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      await setPhoneSize(tester, size);
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byKey(VerifyOtpKeys.card), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
