import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/circle_permission_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/create_circle_screen.dart';

void main() {
  Widget buildScreen({
    VoidCallback? onBack,
    VoidCallback? onCreateCircle,
    EdgeInsets safePadding = EdgeInsets.zero,
  }) {
    return MaterialApp(
      theme: ThemeData(fontFamily: AppTypography.fontFamily),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: safePadding),
          child: child!,
        );
      },
      home: CirclePermissionScreen(
        onBack: onBack ?? () {},
        onCreateCircle: onCreateCircle ?? () {},
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('top bar respects SafeArea and exact requested spacing', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildScreen(safePadding: const EdgeInsets.only(top: 24, bottom: 34)),
    );
    await tester.pumpAndSettle();

    final backRect = tester.getRect(
      find.byKey(CirclePermissionKeys.backButton),
    );
    final titleRect = tester.getRect(find.byKey(CirclePermissionKeys.title));
    final firstRowRect = tester.getRect(
      find.byKey(CirclePermissionKeys.row(0)),
    );

    expect(backRect.top, closeTo(44, 0.01));
    expect(backRect.width, closeTo(30, 0.01));
    expect(backRect.height, closeTo(30, 0.01));
    expect(titleRect.left - backRect.right, closeTo(10, 0.01));
    expect(firstRowRect.top - backRect.bottom, closeTo(20, 0.01));

    final title = tester.widget<Text>(find.byKey(CirclePermissionKeys.title));
    expect(title.style?.fontFamily, 'Poppins');
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.style?.color, const Color(0xFF333333));
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <(Size, double)>[
    (const Size(320, 568), 62),
    (const Size(390, 844), 68),
    (const Size(430, 932), 68),
  ]) {
    testWidgets(
      'permission rows use responsive 68px reference height at ${testCase.$1.width}x${testCase.$1.height}',
      (tester) async {
        await setPhoneSize(tester, testCase.$1);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        for (var index = 0; index < 5; index++) {
          final rect = tester.getRect(
            find.byKey(CirclePermissionKeys.row(index)),
          );
          expect(rect.height, closeTo(testCase.$2, 0.05));
          if (index < 4) {
            final nextRect = tester.getRect(
              find.byKey(CirclePermissionKeys.row(index + 1)),
            );
            expect(nextRect.top - rect.bottom, closeTo(10, 0.01));
          }
        }

        expect(
          tester.getSize(find.byKey(CirclePermissionKeys.iconCircle(0))),
          const Size(36, 36),
        );
        expect(
          tester.getSize(find.byKey(CirclePermissionKeys.toggle(0))),
          const Size(24, 24),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('permission labels use Poppins Medium 15 and #0F1724', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    for (final label in <String>[
      'Live Location',
      'Moment Sharing',
      'Ping',
      'SOS Alerts',
      'Emoji & Gifting',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontFamily, 'Poppins');
      expect(text.style?.fontSize, 15);
      expect(text.style?.fontWeight, FontWeight.w500);
      expect(text.style?.color, const Color(0xFF0F1724));
    }
  });

  testWidgets('toggle updates immediately and independently', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    BoxDecoration decorationFor(int index) {
      final animated = tester.widget<AnimatedContainer>(
        find.byKey(CirclePermissionKeys.toggleTrack(index)),
      );
      return animated.decoration! as BoxDecoration;
    }

    expect(decorationFor(0).color, const Color(0xFF9A48EA));
    expect(decorationFor(2).color, const Color(0xFFD4D4D4));

    await tester.tap(find.byKey(CirclePermissionKeys.toggle(2)));
    await tester.pumpAndSettle();

    expect(decorationFor(0).color, const Color(0xFF9A48EA));
    expect(decorationFor(2).color, const Color(0xFF9A48EA));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create Circle CTA aligns with Create Circle Next CTA', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    final permissionButton = tester.getRect(
      find.byKey(CirclePermissionKeys.createCircleButton),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: AppTypography.fontFamily),
        home: CreateCircleScreen(onNext: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final createCircleNext = tester.getRect(
      find.byKey(CreateCircleKeys.nextButton),
    );

    expect(permissionButton.top, closeTo(createCircleNext.top, 0.01));
    expect(permissionButton.height, closeTo(createCircleNext.height, 0.01));
    expect(permissionButton.left, closeTo(createCircleNext.left, 0.01));
    expect(permissionButton.right, closeTo(createCircleNext.right, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Circle Permission has no overflow at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(
          find.byKey(CirclePermissionKeys.createCircleButton),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('screen keeps the shared #F9F9F9 background', () {
    expect(AppColors.background, const Color(0xFFF9F9F9));
  });
}
