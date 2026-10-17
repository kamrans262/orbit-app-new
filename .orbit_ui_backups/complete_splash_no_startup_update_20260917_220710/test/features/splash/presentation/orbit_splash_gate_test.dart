import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  testWidgets('shows splash first and then reveals the existing app root', (
    WidgetTester tester,
  ) async {
    var completed = 0;

    await tester.pumpWidget(
      OrbitSplashGate(
        displayDuration: const Duration(milliseconds: 100),
        fadeDuration: const Duration(milliseconds: 40),
        onSplashFinished: () {
          completed++;
        },
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: Colors.white,
            child: Center(child: Text('ORBIT APP')),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('orbit-splash-image')),
      findsOneWidget,
    );
    expect(find.text('ORBIT APP'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));

    expect(completed, 1);
    expect(find.text('ORBIT APP'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 40));

    expect(
      find.byKey(const ValueKey<String>('orbit-splash-image')),
      findsNothing,
    );
    expect(find.text('ORBIT APP'), findsOneWidget);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remains overflow-safe at 320x568', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const OrbitSplashGate(
        displayDuration: Duration(seconds: 10),
        child: SizedBox.expand(),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('orbit-splash-image')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
