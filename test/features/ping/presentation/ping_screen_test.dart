import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/ping/presentation/screens/ping_screen.dart';

void main() {
  testWidgets(
    'Ping screen is scroll-safe on a compact phone and sends option',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: PingScreen.demo(
            onSendPing: (submission) => sent = submission.type,
          ),
        ),
      );

      expect(find.text('Ping'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Call me'), findsOneWidget);
      expect(find.text('Custom Message'), findsOneWidget);

      await tester.tap(find.byKey(PingKeys.option('hello')));
      await tester.pump();
      expect(sent, 'hello');
      expect(tester.takeException(), isNull);
    },
  );
}
