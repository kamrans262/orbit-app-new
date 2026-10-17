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

  testWidgets('Welcome keeps requested logo heading and body spacing', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    final logoRect = tester.getRect(find.byKey(WelcomeKeys.logo));
    final headingRect = tester.getRect(find.byKey(WelcomeKeys.heading));
    final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));
    final imageRect = tester.getRect(find.byKey(WelcomeIllustration.imageKey));

    expect(headingRect.top - logoRect.bottom, closeTo(30, 0.01));
    expect(bodyRect.top - headingRect.bottom, closeTo(10, 0.01));
    expect(imageRect.top - bodyRect.bottom, closeTo(14, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome keeps the 10px gap between its buttons', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    final primaryRect = tester.getRect(
      find.byKey(WelcomeKeys.getStartedButton),
    );
    final secondaryRect = tester.getRect(find.byKey(WelcomeKeys.logInButton));
    expect(secondaryRect.top - primaryRect.bottom, closeTo(10, 0.01));
  });

  testWidgets('Welcome image remains full width and preserves natural flow', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(WelcomeIllustration.imageKey)).width,
      closeTo(390, 0.01),
    );
    expect(find.byKey(WelcomeKeys.content), findsOneWidget);
    expect(find.byIcon(Icons.location_on_rounded), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('second screen retains exact 20px heading body image gaps', (
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
      'Welcome remains overflow-safe and CTA aligned at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildWelcome1());
        await tester.pumpAndSettle();
        final screen1ButtonTop = tester
            .getRect(find.byKey(WelcomeKeys.getStartedButton))
            .top;
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildWelcome2());
        await tester.pumpAndSettle();
        final screen2ButtonTop = tester
            .getRect(find.byKey(Welcome2Keys.nextButton))
            .top;
        expect(screen2ButtonTop, closeTo(screen1ButtonTop, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Welcome buttons remain responsive and equal width', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(buildWelcome1());
    await tester.pumpAndSettle();

    final primarySize = tester.getSize(
      find.byKey(WelcomeKeys.getStartedButton),
    );
    final secondarySize = tester.getSize(find.byKey(WelcomeKeys.logInButton));
    expect(primarySize.height, inInclusiveRange(50.0, 54.0));
    expect(primarySize.width, secondarySize.width);
    expect(primarySize.width, lessThan(320));
    expect(tester.takeException(), isNull);
  });

  test('shared visual tokens remain unchanged', () {
    expect(AppTypography.largeHeading.fontSize, 29);
    expect(AppTypography.body.fontSize, 14);
    expect(AppTypography.button.fontSize, 16);
    expect(AppTypography.button.fontWeight, FontWeight.w600);
    expect(AppColors.primaryStart, const Color(0xFFED65C9));
    expect(AppColors.primaryEnd, const Color(0xFF7C3AED));
    expect(AppPrimaryButton.radius, 30);
  });
}
