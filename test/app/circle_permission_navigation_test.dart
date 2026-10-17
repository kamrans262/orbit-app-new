import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/circle_permission_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/create_circle_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Create Circle Next opens Circle Permission and Back returns', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(const OrbitApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.createCircle);
    await tester.pumpAndSettle();

    final nextButton = find.byKey(CreateCircleKeys.nextButton);
    expect(nextButton, findsOneWidget);
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    expect(nextButton.hitTestable(), findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.byType(CirclePermissionScreen), findsOneWidget);

    final backButton = find.byKey(CirclePermissionKeys.backButton);
    expect(backButton.hitTestable(), findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(CreateCircleScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
