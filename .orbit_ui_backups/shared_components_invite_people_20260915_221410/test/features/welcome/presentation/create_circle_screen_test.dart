import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/create_circle_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome_screen.dart';

void main() {
  Widget buildScreen() {
    return MaterialApp(
      theme: ThemeData(fontFamily: AppTypography.fontFamily),
      home: CreateCircleScreen(onNext: () {}),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Create Circle matches required typography and dimensions', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.byKey(CreateCircleKeys.heading));
    final nameLabel = tester.widget<Text>(
      find.byKey(CreateCircleKeys.nameLabel),
    );
    final fieldRect = tester.getRect(find.byKey(CreateCircleKeys.nameField));

    expect(heading.style?.fontFamily, 'Poppins');
    expect(heading.style?.fontSize, 29);
    expect(heading.style?.fontWeight, FontWeight.w600);
    expect(nameLabel.style?.fontFamily, 'Poppins');
    expect(nameLabel.style?.fontSize, 14);
    expect(nameLabel.style?.fontWeight, FontWeight.w400);
    expect(fieldRect.height, closeTo(46, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('name field has 15px inner left padding', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;
    final padding = decoration.contentPadding! as EdgeInsets;

    expect(padding.left, 15);
    expect(textField.style?.fontFamily, 'Poppins');
    expect(textField.style?.fontSize, 14);
  });

  testWidgets('color choices keep exactly 10px horizontal gaps', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    for (var index = 0; index < 6; index++) {
      final current = tester.getRect(find.byKey(CreateCircleKeys.color(index)));
      final next = tester.getRect(
        find.byKey(CreateCircleKeys.color(index + 1)),
      );
      expect(next.left - current.right, closeTo(10, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon choices keep exactly 20px horizontal gaps', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      final current = tester.getRect(find.byKey(CreateCircleKeys.icon(index)));
      final next = tester.getRect(find.byKey(CreateCircleKeys.icon(index + 1)));
      expect(next.left - current.right, closeTo(20, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('only one color and one icon are selected at a time', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CreateCircleKeys.color(3)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CreateCircleKeys.icon(4)));
    await tester.pumpAndSettle();

    final oldColorScale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byKey(CreateCircleKeys.color(0)),
        matching: find.byType(AnimatedScale),
      ),
    );
    final newColorScale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byKey(CreateCircleKeys.color(3)),
        matching: find.byType(AnimatedScale),
      ),
    );
    final oldIcon = tester.widget<Material>(
      find.byKey(CreateCircleKeys.icon(0)),
    );
    final newIcon = tester.widget<Material>(
      find.byKey(CreateCircleKeys.icon(4)),
    );

    expect(oldColorScale.scale, 0.94);
    expect(newColorScale.scale, 1);
    expect(oldIcon.color, Colors.white);
    expect(newIcon.color, const Color(0x1A7C3AED));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Create Circle has no overflow at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();
        expect(find.byKey(CreateCircleKeys.nextButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Create Circle Next aligns with onboarding primary CTA', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    final createCircleButton = tester.getRect(
      find.byKey(CreateCircleKeys.nextButton),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: AppTypography.fontFamily),
        home: WelcomeScreen(onGetStarted: () {}, onLogIn: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final welcomeButton = tester.getRect(
      find.byKey(WelcomeKeys.getStartedButton),
    );

    expect(createCircleButton.top, closeTo(welcomeButton.top, 0.01));
    expect(createCircleButton.height, closeTo(welcomeButton.height, 0.01));
    expect(tester.takeException(), isNull);
  });

  test('shared background remains #F9F9F9', () {
    expect(AppColors.background, const Color(0xFFF9F9F9));
  });
}
