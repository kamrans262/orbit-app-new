import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_theme.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.light,
      home: Welcome2Screen(onNext: () {}),
    );
  }

  Future<void> pumpAtSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
  }

  testWidgets('renders second welcome content', (tester) async {
    await pumpAtSize(tester, const Size(390, 844));

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

  test('keeps reusable muted color and Poppins typography', () {
    expect(AppColors.textMuted, const Color(0xFF94A3B8));
    expect(AppTypography.bodyMuted.color, AppColors.textMuted);
    expect(AppTypography.fontFamily, 'Poppins');
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Poppins');
  });
}
