import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/connectivity/domain/orbit_connection_probe.dart';
import 'package:orbit_ui/features/connectivity/presentation/orbit_connectivity_runtime.dart';

void main() {
  final observer = OrbitConnectivityNavigatorObserver.instance;

  setUp(() {
    observer.resetSessionState();
    OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;
    OrbitConnectivityNavigatorObserver.pollInterval = const Duration(hours: 1);
  });

  tearDown(() {
    observer.resetSessionState();
    OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;
    OrbitConnectionProbe.reset();
  });

  testWidgets('app-wide observer shows offline popup over current route', (
    tester,
  ) async {
    OrbitConnectionProbe.check = () async => false;
    OrbitConnectivityNavigatorObserver.autoMonitorEnabled = true;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: const Scaffold(body: Center(child: Text('Underlying Screen'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('Underlying Screen'), findsOneWidget);
    expect(find.text('You’re Offline'), findsOneWidget);
  });

  testWidgets('online state does not show offline popup', (tester) async {
    OrbitConnectionProbe.check = () async => true;
    OrbitConnectivityNavigatorObserver.autoMonitorEnabled = true;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: const Scaffold(body: Center(child: Text('Online Screen'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('Online Screen'), findsOneWidget);
    expect(find.text('You’re Offline'), findsNothing);
  });
}
