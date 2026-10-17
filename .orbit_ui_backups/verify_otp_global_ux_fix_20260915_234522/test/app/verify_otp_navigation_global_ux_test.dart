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

  testWidgets('Orbit app installs global keyboard dismiss and fade-slide theme', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(const OrbitApp());
    await tester.pump();

    expect(find.byType(AppKeyboardDismiss), findsOneWidget);

    final welcomeContext = tester.element(find.byType(WelcomeScreen));
    final transitions = Theme.of(welcomeContext).pageTransitionsTheme.builders;
    expect(
      transitions.values.whereType<AppFadeSlidePageTransitionsBuilder>(),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reset Password sends the entered recipient to OTP route', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(const OrbitApp());
    await tester.pump();

    final context = tester.element(find.byType(WelcomeScreen));
    Navigator.of(context).pushNamed(AppRoutes.resetPassword);
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'person@example.com');

    final button = find.byKey(ResetPasswordKeys.sendResetLinkButton);
    await tester.ensureVisible(button);
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(VerifyOtpScreen), findsOneWidget);
    expect(
      find.text('We sent a 6-digit code to\nperson@example.com'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
