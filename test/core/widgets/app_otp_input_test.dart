import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_otp_input.dart';

void main() {
  Widget buildOtp({ValueChanged<String>? onChanged}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppOtpInput(onChanged: onChanged ?? (_) {}),
          ),
        ),
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('OTP matches latest Figma styling and stays responsive', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(buildOtp());
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(6));

    for (var index = 1; index <= 6; index++) {
      final boxFinder = find.byKey(ValueKey<String>('otp_box_$index'));
      final fieldFinder = find.byKey(ValueKey<String>('otp_field_$index'));
      final rect = tester.getRect(boxFinder);
      final box = tester.widget<Container>(boxFinder);
      final decoration = box.decoration! as BoxDecoration;
      final field = tester.widget<TextField>(fieldFinder);
      final padding = field.decoration!.contentPadding! as EdgeInsets;

      expect(rect.width, lessThanOrEqualTo(AppOtpInput.referenceBoxWidth));
      expect(rect.height, AppOtpInput.referenceBoxHeight);
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(30));
      expect(decoration.boxShadow?.single.blurRadius, 2);
      expect(decoration.boxShadow?.single.spreadRadius, 0);
      expect(decoration.boxShadow?.single.color, const Color(0x1A000000));
      expect(field.style?.fontFamily, 'Poppins');
      expect(field.style?.fontSize, 14);
      expect(field.style?.fontWeight, FontWeight.w400);
      expect(field.style?.letterSpacing, 0);
      expect(field.style?.color, const Color(0xFF0F1724));
      expect(field.decoration?.hintStyle?.color, const Color(0xFFBFC0C0));
      expect(padding.top, 13);
      expect(padding.right, 14);
      expect(padding.bottom, 13);
      expect(padding.left, 14);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('pasting six digits distributes them across all boxes', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    String? code;
    await tester.pumpWidget(buildOtp(onChanged: (value) => code = value));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('otp_field_1')),
      '123456',
    );
    await tester.pump();

    for (var index = 1; index <= 6; index++) {
      final field = tester.widget<TextField>(
        find.byKey(ValueKey<String>('otp_field_$index')),
      );
      expect(field.controller?.text, '$index');
    }
    expect(code, '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('single digit advances focus and deletion moves focus back', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildOtp());
    await tester.pump();

    final firstFinder = find.byKey(const ValueKey<String>('otp_field_1'));
    final secondFinder = find.byKey(const ValueKey<String>('otp_field_2'));

    await tester.tap(firstFinder);
    await tester.enterText(firstFinder, '7');
    await tester.pump();

    var second = tester.widget<TextField>(secondFinder);
    expect(second.focusNode?.hasFocus, isTrue);

    await tester.enterText(secondFinder, '8');
    await tester.pump();
    await tester.enterText(secondFinder, '');
    await tester.pump();

    final first = tester.widget<TextField>(firstFinder);
    second = tester.widget<TextField>(secondFinder);
    expect(first.focusNode?.hasFocus, isTrue);
    expect(second.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
