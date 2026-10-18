import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_otp_sign_in_screen.dart';
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
    expect(find.textContaining('Password sign-in is awaiting client approval'),
        findsOneWidget);

    final otpButton = find.text('Sign in with email or SMS code');
    await tester.ensureVisible(otpButton);
    await tester.tap(otpButton);
    await tester.pumpAndSettle();
    expect(find.byType(OrbitOtpSignInScreen), findsOneWidget);
  });
}
