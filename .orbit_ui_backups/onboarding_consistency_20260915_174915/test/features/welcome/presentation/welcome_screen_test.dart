import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/core/widgets/app_secondary_button.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/welcome_illustration.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }

  Future<void> pumpAtPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
  }

  testWidgets('renders the welcome copy and actions', (tester) async {
    await pumpAtPhoneSize(tester);

    expect(
      find.text('Stay close.\nShare moments.\nLive together.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Orbit helps you stay\nconnected with the\npeople who matter most.',
      ),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('matches the requested first-screen spacing', (tester) async {
    await pumpAtPhoneSize(tester);

    final logoRect = tester.getRect(find.byKey(WelcomeKeys.logo));
    final headingRect = tester.getRect(find.byKey(WelcomeKeys.heading));
    final bodyRect = tester.getRect(find.byKey(WelcomeKeys.body));

    expect(headingRect.top - logoRect.bottom, closeTo(30, 0.01));
    expect(bodyRect.top - headingRect.bottom, closeTo(10, 0.01));

    final primary = find.byKey(WelcomeKeys.getStartedButton);
    final secondary = find.byKey(WelcomeKeys.logInButton);
    await tester.ensureVisible(primary);
    await tester.ensureVisible(secondary);
    await tester.pumpAndSettle();

    final primaryRect = tester.getRect(primary);
    final secondaryRect = tester.getRect(secondary);
    expect(secondaryRect.top - primaryRect.bottom, closeTo(10, 0.01));
  });

  testWidgets('welcome image uses the full available screen width', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester);

    final illustration = find.byKey(WelcomeIllustration.imageKey);
    expect(illustration, findsOneWidget);
    expect(tester.getSize(illustration).width, closeTo(390, 0.01));
  });

  testWidgets('does not duplicate decorative icons over the image', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester);

    expect(find.byIcon(Icons.location_on_rounded), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('uses the required button dimensions', (tester) async {
    await pumpAtPhoneSize(tester);

    final primary = find.byKey(WelcomeKeys.getStartedButton);
    final secondary = find.byKey(WelcomeKeys.logInButton);
    await tester.ensureVisible(primary);
    await tester.ensureVisible(secondary);
    await tester.pumpAndSettle();

    final primarySize = tester.getSize(primary);
    final secondarySize = tester.getSize(secondary);

    expect(primarySize.height, AppPrimaryButton.height);
    expect(secondarySize.height, AppSecondaryButton.height);
    expect(primarySize.width, greaterThan(250));
    expect(primarySize.width, secondarySize.width);
  });

  test('design typography keeps the supplied reference sizes', () {
    expect(AppTypography.largeHeading.fontSize, 29);
    expect(AppTypography.smallHeading.fontSize, 24);
    expect(AppTypography.body.fontSize, 14);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('has no layout exception at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  }
}
