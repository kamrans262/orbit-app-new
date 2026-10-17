import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/circle_permission_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/invite_people_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Create Circle action opens Invite People', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(const OrbitApp());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.circlePermission);
    await tester.pumpAndSettle();

    expect(find.byType(CirclePermissionScreen), findsOneWidget);
    final createButton = find.byKey(CirclePermissionKeys.createCircleButton);
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    expect(createButton.hitTestable(), findsOneWidget);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.byType(InvitePeopleScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
