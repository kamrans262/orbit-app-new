import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  testWidgets('builds splash safely above MaterialApp', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const OrbitSplashGate(
        displayDuration: Duration(seconds: 10),
        child: MaterialApp(home: Scaffold(body: Text('Orbit'))),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('orbit-splash-image')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash occupies the viewport and does not overflow at 320x568', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const OrbitSplashGate(
        displayDuration: Duration(seconds: 10),
        child: MaterialApp(home: SizedBox.expand()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('orbit-splash-image')),
      findsOneWidget,
    );
    expect(find.byType(OrbitSplashGate), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveals Orbit app after splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      const OrbitSplashGate(
        displayDuration: Duration(milliseconds: 100),
        fadeDuration: Duration(milliseconds: 40),
        child: MaterialApp(home: Scaffold(body: Text('ORBIT APP'))),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('ORBIT APP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
