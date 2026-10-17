import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/welcome_illustration.dart';

void main() {
  Widget buildWelcome1() {
    return MaterialApp(
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }

  Widget buildWelcome2() {
    return MaterialApp(home: Welcome2Screen(onNext: () {}));
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('keeps first-screen requested text spacing', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    final logoRect = tester.getRect(find.byKey(WelcomeKeys.logo));
    final headingRect = tester.getRect(find.byKey(WelcomeKeys.heading));
    final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));

    expect(headingRect.top - logoRect.bottom, closeTo(30, 0.01));
    expect(bodyRect.top - headingRect.bottom, closeTo(10, 0.01));
  });

  testWidgets('keeps the 10px gap between first-screen buttons', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    final primaryRect = tester.getRect(
      find.byKey(WelcomeKeys.getStartedButton),
    );
    final secondaryRect = tester.getRect(find.byKey(WelcomeKeys.logInButton));

    expect(secondaryRect.top - primaryRect.bottom, closeTo(10, 0.01));
  });

  testWidgets('welcome image stays full width with no duplicate icons', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(WelcomeIllustration.imageKey)).width,
      closeTo(390, 0.01),
    );
    expect(find.byIcon(Icons.location_on_rounded), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('second screen uses exact 20px heading body image gaps', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome2());
    await tester.pumpAndSettle();

    final headingRect = tester.getRect(find.byKey(Welcome2Keys.heading));
    final bodyRect = tester.getRect(find.byKey(Welcome2Keys.body));
    final mapRect = tester.getRect(find.byKey(Welcome2Keys.map));

    expect(bodyRect.top - headingRect.bottom, closeTo(20, 0.01));
    expect(mapRect.top - bodyRect.bottom, closeTo(20, 0.01));
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'images meet primary buttons with zero gap and buttons align at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);

        await tester.pumpWidget(buildWelcome1());
        await tester.pumpAndSettle();
        final welcomeImageRect = tester.getRect(
          find.byKey(WelcomeIllustration.imageKey),
        );
        final screen1ButtonRect = tester.getRect(
          find.byKey(WelcomeKeys.getStartedButton),
        );

        expect(
          screen1ButtonRect.top - welcomeImageRect.bottom,
          closeTo(0, 0.01),
        );
        final screen1ButtonTop = screen1ButtonRect.top;
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildWelcome2());
        await tester.pumpAndSettle();
        final mapRect = tester.getRect(find.byKey(Welcome2Keys.map));
        final screen2ButtonRect = tester.getRect(
          find.byKey(Welcome2Keys.nextButton),
        );

        expect(screen2ButtonRect.top - mapRect.bottom, closeTo(0, 0.01));
        expect(screen2ButtonRect.top, closeTo(screen1ButtonTop, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('buttons remain responsive and share the same width', (
    tester,
  ) async {
    for (final size in <Size>[
      const Size(320, 568),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(buildWelcome1());
      await tester.pumpAndSettle();

      final primarySize = tester.getSize(
        find.byKey(WelcomeKeys.getStartedButton),
      );
      final secondarySize = tester.getSize(find.byKey(WelcomeKeys.logInButton));

      expect(primarySize.height, inInclusiveRange(50.0, 54.0));
      expect(primarySize.width, secondarySize.width);
      expect(primarySize.width, lessThan(size.width));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  test('shared visual tokens match the supplied specification', () {
    expect(AppTypography.largeHeading.fontSize, 29);
    expect(AppTypography.smallHeading.fontSize, 24);
    expect(AppTypography.body.fontSize, 14);
    expect(AppTypography.button.fontSize, 16);
    expect(AppTypography.button.fontWeight, FontWeight.w600);
    expect(AppColors.primaryStart, const Color(0xFFED65C9));
    expect(AppColors.primaryEnd, const Color(0xFF7C3AED));
    expect(AppPrimaryButton.radius, 30);
  });
}
