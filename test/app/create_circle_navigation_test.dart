import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/create_circle_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/share_location_screen.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Share Location option opens Create Your First Circle', (
    tester,
  ) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.shareLocation);
    await tester.pumpAndSettle();

    expect(find.byType(ShareLocationScreen), findsOneWidget);
    await tapVisible(tester, find.byKey(ShareLocationKeys.allowWhileUsing));

    expect(find.byType(CreateCircleScreen), findsOneWidget);
    expect(find.text('Create Your\nFirst Circle'), findsOneWidget);
  });
}
