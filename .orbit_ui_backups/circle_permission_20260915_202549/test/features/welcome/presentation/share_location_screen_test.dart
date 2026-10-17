import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/share_location_screen.dart';

void main() {
  Widget buildScreen() {
    return MaterialApp(
      home: ShareLocationScreen(
        onAllowAlways: () {},
        onAllowWhileUsing: () {},
        onNotNow: () {},
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('map.png is available in the Flutter asset bundle', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    final data = await rootBundle.load('assets/map.png');
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('Share Location keeps exact heading body image spacing', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final headingRect = tester.getRect(find.byKey(ShareLocationKeys.heading));
    final bodyRect = tester.getRect(find.byKey(ShareLocationKeys.body));
    final imageRect = tester.getRect(find.byKey(ShareLocationKeys.image));

    expect(bodyRect.top - headingRect.bottom, closeTo(10, 0.01));
    expect(imageRect.top - bodyRect.bottom, closeTo(20, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <(Size, double)>[
    (const Size(320, 568), 292),
    (const Size(390, 844), 347),
    (const Size(430, 932), 347),
  ]) {
    testWidgets(
      'permission card is responsive and image ends halfway under it at ${testCase.$1.width}x${testCase.$1.height}',
      (tester) async {
        await setPhoneSize(tester, testCase.$1);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final cardRect = tester.getRect(
          find.byKey(ShareLocationKeys.permissionCard),
        );
        final imageRect = tester.getRect(find.byKey(ShareLocationKeys.image));

        expect(cardRect.width, closeTo(testCase.$2, 0.01));
        expect(cardRect.height, closeTo(256, 0.01));
        expect(testCase.$1.height - cardRect.bottom, closeTo(40, 0.01));
        expect(
          imageRect.bottom,
          closeTo(cardRect.top + (cardRect.height / 2), 0.01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('permission card uses 14 horizontal padding and 18 black text', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final optionFinder = find.byKey(ShareLocationKeys.allowAlways);
    final textWidget = tester.widget<Text>(
      find.descendant(of: optionFinder, matching: find.text('Allow Always')),
    );
    final paddingFinder = find.descendant(
      of: optionFinder,
      matching: find.byType(Padding),
    );
    final optionPadding = tester
        .widgetList<Padding>(paddingFinder)
        .firstWhere(
          (widget) =>
              widget.padding is EdgeInsets &&
              (widget.padding as EdgeInsets).left == 14 &&
              (widget.padding as EdgeInsets).right == 14,
        );

    expect((optionPadding.padding as EdgeInsets).left, 14);
    expect((optionPadding.padding as EdgeInsets).right, 14);
    expect(textWidget.style?.fontSize, 18);
    expect(textWidget.style?.color, Colors.black);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission card exposes all three options', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Allow Always'), findsOneWidget);
    expect(find.text('Allow While Using App'), findsOneWidget);
    expect(find.text('Not Now'), findsOneWidget);
    expect(find.byKey(ShareLocationKeys.allowAlways), findsOneWidget);
    expect(find.byKey(ShareLocationKeys.allowWhileUsing), findsOneWidget);
    expect(find.byKey(ShareLocationKeys.notNow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('shared onboarding background remains #F9F9F9', () {
    expect(AppColors.background, const Color(0xFFF9F9F9));
  });
}
