import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/sos/presentation/screens/sos_alert_screen.dart';

void main() {
  Future<void> pumpAtSize(WidgetTester tester, Size size, Widget child) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  testWidgets('SOS screen is scroll-safe on compact phones', (
    WidgetTester tester,
  ) async {
    await pumpAtSize(tester, const Size(320, 568), SosAlertScreen.demo());

    expect(find.text('SOS Alert'), findsOneWidget);
    expect(
      find.text('Hold for 3 seconds to alert your circle'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Call\n911'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding SOS for 3 seconds triggers exactly once', (
    WidgetTester tester,
  ) async {
    var triggered = 0;
    await pumpAtSize(
      tester,
      const Size(390, 844),
      SosAlertScreen(onAlertTriggered: (_) => triggered += 1),
    );

    final button = find.byKey(const ValueKey<String>('sos-trigger-button'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    // Deliver onTapDown and start the AnimationController in an initial frame
    // before advancing the virtual clock for the three-second hold.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(seconds: 3, milliseconds: 50));
    expect(triggered, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(triggered, 1);
  });
}
