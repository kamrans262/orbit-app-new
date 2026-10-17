import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/presentation/screens/login_screen.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('Login primary action opens Home for current UI-only flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OrbitApp());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final loginButton = find.byKey(LoginKeys.loginButton);
    await tester.ensureVisible(loginButton);
    expect(loginButton.hitTestable(), findsOneWidget);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
