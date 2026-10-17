import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/notifications_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/share_location_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/share_moments_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/your_circle_screen.dart';

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

  Future<void> navigateToNotifications(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(WelcomeKeys.getStartedButton));
    await tapVisible(tester, find.byKey(Welcome2Keys.nextButton));
    await tapVisible(tester, find.byKey(ShareMomentsKeys.nextButton));
    await tapVisible(tester, find.byKey(YourCircleKeys.nextButton));
  }

  testWidgets('Get Started opens the second welcome screen', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(WelcomeKeys.getStartedButton));

    expect(find.byType(Welcome2Screen), findsOneWidget);
    expect(find.text('Live. Share. Protect'), findsOneWidget);
  });

  testWidgets('second welcome Next opens Share Moments', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(WelcomeKeys.getStartedButton));
    await tapVisible(tester, find.byKey(Welcome2Keys.nextButton));

    expect(find.byType(ShareMomentsScreen), findsOneWidget);
    expect(find.text('Share Moments'), findsOneWidget);
    expect(find.byKey(ShareMomentsKeys.image), findsOneWidget);
  });

  testWidgets('Share Moments Next opens Your Circle', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(WelcomeKeys.getStartedButton));
    await tapVisible(tester, find.byKey(Welcome2Keys.nextButton));
    await tapVisible(tester, find.byKey(ShareMomentsKeys.nextButton));

    expect(find.byType(YourCircleScreen), findsOneWidget);
    expect(find.text('Your Circle'), findsOneWidget);
    expect(find.byKey(YourCircleKeys.image), findsOneWidget);
  });

  testWidgets('Your Circle Next opens Notifications', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    await navigateToNotifications(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('Stay In the loop'), findsOneWidget);
    expect(find.byKey(NotificationsKeys.image), findsOneWidget);
  });

  testWidgets('Notifications Allow opens Share Location', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    await navigateToNotifications(tester);
    await tapVisible(tester, find.byKey(NotificationsKeys.allowButton));

    expect(find.byType(ShareLocationScreen), findsOneWidget);
    expect(find.text('Share Location'), findsOneWidget);
    expect(find.byKey(ShareLocationKeys.permissionCard), findsOneWidget);
  });

  testWidgets('Notifications Not Now opens Share Location', (tester) async {
    await usePhoneViewport(tester);

    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    await navigateToNotifications(tester);
    await tapVisible(tester, find.byKey(NotificationsKeys.notNowButton));

    expect(find.byType(ShareLocationScreen), findsOneWidget);
    expect(find.byKey(ShareLocationKeys.image), findsOneWidget);
  });
}
