import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';
import 'package:orbit_ui/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_card.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_header.dart';

void main() {
  Widget buildScreen({ValueChanged<String>? onSubmit}) {
    return MaterialApp(
      home: ResetPasswordScreen(onSendResetLink: onSubmit ?? (_) {}),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'Reset Password reuses shared auth components and exact spacing',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(AuthCard), findsOneWidget);
      expect(find.byType(AuthHeader), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);

      final cardRect = tester.getRect(find.byKey(ResetPasswordKeys.card));
      final headingRect = tester.getRect(find.byKey(ResetPasswordKeys.heading));
      final fieldRect = tester.getRect(
        find.byKey(ResetPasswordKeys.emailOrPhoneField),
      );
      final buttonRect = tester.getRect(
        find.byKey(ResetPasswordKeys.sendResetLinkButton),
      );

      expect(headingRect.top - cardRect.top, closeTo(36, 0.01));
      expect(buttonRect.top - fieldRect.bottom, closeTo(25, 0.01));
      expect(find.text('Reset Your Password'), findsOneWidget);
      expect(find.text('Enter Your Phone or Email'), findsOneWidget);
      expect(find.text('Enter Email / Phone'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Reset Password stays scroll-safe at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byKey(ResetPasswordKeys.card), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Send Reset Link forwards the current field value', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    String? submitted;
    await tester.pumpWidget(
      buildScreen(onSubmit: (value) => submitted = value),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'person@example.com');
    final button = find.byKey(ResetPasswordKeys.sendResetLinkButton);
    await tester.ensureVisible(button);
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pump();

    expect(submitted, 'person@example.com');
    expect(tester.takeException(), isNull);
  });
}
