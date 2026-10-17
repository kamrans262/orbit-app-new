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

  testWidgets('OTP remains responsive without overflow on compact phones', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(buildOtp());
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(6));
    for (var index = 1; index <= 6; index++) {
      final rect = tester.getRect(
        find.byKey(ValueKey<String>('otp_box_$index')),
      );
      expect(rect.width, lessThanOrEqualTo(AppOtpInput.referenceBoxWidth));
      expect(rect.height, AppOtpInput.referenceBoxHeight);
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
    expect(first.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
