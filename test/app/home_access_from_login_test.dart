import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_otp_verification_controller.dart';
import 'package:orbit_ui/features/auth/presentation/screens/verify_otp_screen.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('Login no longer bypasses authentication to Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const OrbitApp());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();

    final login = find.byKey(LoginKeys.loginButton);
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.textContaining('Enter your email or phone and password.'),
        findsOneWidget);

    expect(find.text('Continue with a code'), findsNothing);
    expect(find.byType(OrbitOtpVerificationController), findsNothing);
    expect(find.byType(VerifyOtpScreen), findsNothing);
  });
}
