import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/app/theme/app_page_transitions.dart';
import 'package:orbit_ui/core/widgets/app_keyboard_dismiss.dart';
import 'package:orbit_ui/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/verify_otp_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'Orbit app installs global keyboard dismiss and fade-slide theme',
    (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(const OrbitApp());
      await tester.pump();

      expect(find.byType(AppKeyboardDismiss), findsOneWidget);

      final welcomeContext = tester.element(find.byType(WelcomeScreen));
      final transitions = Theme.of(welcomeContext)
          .pageTransitionsTheme
          .builders;
      expect(
        transitions.values.whereType<AppFadeSlidePageTransitionsBuilder>(),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reset Password does not bypass server verification', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(const OrbitApp());
    await tester.pump();

    final context = tester.element(find.byType(WelcomeScreen));
    Navigator.of(context).pushNamed(AppRoutes.resetPassword);
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    // Recovery now waits for a real API response before opening OTP;
    // no fake OTP route or made-up recipient is used.
    expect(find.byType(VerifyOtpScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
