import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/check_in/domain/models/check_in_models.dart';
import 'package:orbit_ui/features/check_in/presentation/screens/check_in_screen.dart';

void main() {
  Future<void> pumpAtSize(
    WidgetTester tester,
    Size size, {
    ValueChanged<CheckInSubmission>? onSent,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CheckInScreen.demo(onCheckInSent: onSent),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('is overflow-safe at ${size.width}x${size.height}', (tester) async {
      await pumpAtSize(tester, size);
      expect(find.text('Check-In'), findsOneWidget);
      expect(find.text('Tap or hold to send'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pulse system is centered in the usable viewport on normal phones', (tester) async {
    const size = Size(390, 844);
    await pumpAtSize(tester, size);

    final heartRect = tester.getRect(find.byKey(CheckInKeys.heart));
    final safeTop = tester.view.padding.top / tester.view.devicePixelRatio;
    final safeBottom = tester.view.padding.bottom / tester.view.devicePixelRatio;
    final usableCenterY = safeTop + ((size.height - safeTop - safeBottom) / 2);

    expect((heartRect.center.dy - usableCenterY).abs(), lessThanOrEqualTo(1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity selection is exclusive and tap submits selection', (tester) async {
    CheckInSubmission? submission;
    await pumpAtSize(
      tester,
      const Size(390, 844),
      onSent: (value) => submission = value,
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CheckInKeys.heart));
    await tester.pump(const Duration(milliseconds: 2400));

    expect(submission?.activityId, 'home');
    expect(submission?.interactionType, CheckInInteractionType.tap);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close action pops screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => CheckInScreen.demo()),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CheckInKeys.close));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
