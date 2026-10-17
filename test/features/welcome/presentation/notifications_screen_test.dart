import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/notifications_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  Widget buildNotifications() {
    return MaterialApp(
      home: NotificationsScreen(onAllowNotification: () {}, onNotNow: () {}),
    );
  }

  Widget buildWelcome1() {
    return MaterialApp(
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Notifcation.png is available in the Flutter asset bundle', (
    tester,
  ) async {
    await tester.pumpWidget(buildNotifications());
    final data = await rootBundle.load('assets/Notifcation.png');
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('Notifications keeps exact heading body image spacing', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildNotifications());
    await tester.pumpAndSettle();

    final headingRect = tester.getRect(find.byKey(NotificationsKeys.heading));
    final bodyRect = tester.getRect(find.byKey(NotificationsKeys.body));
    final imageRect = tester.getRect(find.byKey(NotificationsKeys.image));

    expect(bodyRect.top - headingRect.bottom, closeTo(10, 0.01));
    expect(imageRect.top - bodyRect.bottom, closeTo(66, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Notifications buttons align with Welcome buttons at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);

        await tester.pumpWidget(buildWelcome1());
        await tester.pumpAndSettle();
        final welcomePrimaryRect = tester.getRect(
          find.byKey(WelcomeKeys.getStartedButton),
        );
        final welcomeSecondaryRect = tester.getRect(
          find.byKey(WelcomeKeys.logInButton),
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildNotifications());
        await tester.pumpAndSettle();
        final imageRect = tester.getRect(find.byKey(NotificationsKeys.image));
        final primaryRect = tester.getRect(
          find.byKey(NotificationsKeys.allowButton),
        );
        final secondaryRect = tester.getRect(
          find.byKey(NotificationsKeys.notNowButton),
        );

        expect(primaryRect.top, closeTo(welcomePrimaryRect.top, 0.01));
        expect(secondaryRect.top, closeTo(welcomeSecondaryRect.top, 0.01));
        expect(primaryRect.top - imageRect.bottom, closeTo(0, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('shared onboarding background remains #F9F9F9', () {
    expect(AppColors.background, const Color(0xFFF9F9F9));
  });
}
