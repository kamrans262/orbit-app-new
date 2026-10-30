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

  testWidgets('More uses the Orbit custom Check-In sheet and heart submits text',
      (tester) async {
    CheckInSubmission? sent;
    await pumpAtSize(tester,const Size(390,844),onSent:(value)=>sent=value);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_circle_sheet_surface')),findsOneWidget);
    await tester.enterText(find.byKey(const Key('check_in_custom_field')),
      'Working on the garden');
    await tester.tap(find.text('Use this update'));
    await tester.pumpAndSettle();
    expect(find.text('Working on the garden'),findsOneWidget);
    await tester.tap(find.byKey(CheckInKeys.heart));
    await tester.pump(const Duration(milliseconds:2400));
    expect(sent?.activityId,'custom');
    expect(sent?.customText,'Working on the garden');
    expect(tester.takeException(),isNull);
  });

  testWidgets('history links remain optional and do not change the approved layout',
      (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var viewed=0;
    await tester.pumpWidget(MaterialApp(home:CheckInScreen.demo(
      onViewHistory:()=>viewed++,onViewFeed:()=>viewed+=10)));
    await tester.pumpAndSettle();
    expect(find.text('How are you?'),findsOneWidget);
    expect(find.text('Tap or hold to send'),findsOneWidget);
    await tester.ensureVisible(find.text('My Check-Ins'));
    await tester.tap(find.text('My Check-Ins'));
    expect(viewed,1);
    await tester.ensureVisible(find.text('Friends’ Check-Ins'));
    await tester.tap(find.text('Friends’ Check-Ins'));
    expect(viewed,11);
  });
}
