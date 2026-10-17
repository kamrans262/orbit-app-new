import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/core/widgets/app_secondary_button.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
    );
  }

  testWidgets('renders the welcome copy and actions', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

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

  testWidgets('uses the required button dimensions', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final primarySize = tester.getSize(
      find.byKey(WelcomeKeys.getStartedButton),
    );
    final secondarySize = tester.getSize(find.byKey(WelcomeKeys.logInButton));

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
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  }
}
