import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_theme.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.light,
      home: Welcome2Screen(onNext: () {}),
    );
  }

  testWidgets('renders the second welcome screen content', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Live. Share. Protect'), findsOneWidget);
    expect(
      find.text(
        "See where your people are in\nreal-time and know they're\nsafe.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(Welcome2Keys.map), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('uses the shared primary button dimensions', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final size = tester.getSize(find.byKey(Welcome2Keys.nextButton));
    expect(size.height, AppPrimaryButton.height);
    expect(size.width, greaterThan(250));
  });

  test('uses reusable muted text color and Poppins typography', () {
    expect(AppColors.textMuted, const Color(0xFF94A3B8));
    expect(AppTypography.bodyMuted.color, AppColors.textMuted);
    expect(AppTypography.fontFamily, 'Poppins');
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Poppins');
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
      expect(find.byType(Welcome2Screen), findsOneWidget);
    });
  }
}
