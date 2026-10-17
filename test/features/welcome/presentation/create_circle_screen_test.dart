import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_text_field.dart';
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

  testWidgets(
    'Create Circle uses the shared AppTextField without visual change',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(AppTextField), findsOneWidget);
      final heading = tester.widget<Text>(find.byKey(CreateCircleKeys.heading));
      final nameLabel = tester.widget<Text>(
        find.byKey(CreateCircleKeys.nameLabel),
      );
      final fieldRect = tester.getRect(find.byKey(CreateCircleKeys.nameField));
      final textField = tester.widget<TextField>(find.byType(TextField));
      final padding = textField.decoration!.contentPadding! as EdgeInsets;

      expect(heading.style?.fontFamily, 'Poppins');
      expect(heading.style?.fontSize, 29);
      expect(heading.style?.fontWeight, FontWeight.w600);
      expect(nameLabel.style?.fontFamily, 'Poppins');
      expect(nameLabel.style?.fontSize, 14);
      expect(nameLabel.style?.fontWeight, FontWeight.w500);
      expect(fieldRect.height, 49);
      expect(padding.left, 14);
      expect(textField.style?.fontFamily, 'Poppins');
      expect(textField.style?.fontSize, 15);
      expect(tester.takeException(), isNull);
    },
  );

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
