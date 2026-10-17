import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  testWidgets('shows splash first and then reveals existing app', (tester) async {
    await tester.pumpWidget(
      const OrbitSplashGate(
        displayDuration: Duration(milliseconds: 50),
        fadeDuration: Duration(milliseconds: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Existing Orbit App'),
        ),
      ),
    );

    expect(find.byKey(const Key('orbit-splash-image')), findsOneWidget);
    expect(find.text('Existing Orbit App'), findsNothing);

    await tester.pump(const Duration(milliseconds: 55));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit-splash-image')), findsNothing);
    expect(find.text('Existing Orbit App'), findsOneWidget);
  });

  testWidgets('remains overflow-safe at 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const OrbitSplashGate(
        displayDuration: Duration(days: 1),
        child: SizedBox.shrink(),
      ),
    );

    expect(find.byKey(const Key('orbit-splash-image')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
