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
            recipientOrCircleId: '11111111-1111-4111-8111-111111111111',
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

  testWidgets('Failed Ping offers retry and clears failed state on success',(tester) async {
    var attempts=0;
    await tester.pumpWidget(MaterialApp(home:PingScreen.demo(
      recipientOrCircleId:'11111111-1111-4111-8111-111111111111',
      onSendPing:(_) async {
        attempts++;
        if(attempts==1)throw StateError('service');
      },
    )));
    await tester.tap(find.byKey(PingKeys.option('hello')));
    await tester.pumpAndSettle();
    expect(find.byKey(PingKeys.retry),findsOneWidget);
    await tester.ensureVisible(find.byKey(PingKeys.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PingKeys.retry));
    await tester.pumpAndSettle();
    expect(attempts,2);
    expect(find.byKey(PingKeys.retry),findsNothing);
  });

  testWidgets('demo Ping without a verified recipient never claims success',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: PingScreen.demo()));
    await tester.tap(find.byKey(PingKeys.option('hello')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose an authorized recipient'), findsOneWidget);
    expect(find.textContaining('ping sent'), findsNothing);
  });
}
