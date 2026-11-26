import 'dart:async';
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
    OrbitConnectivityNavigatorObserver.startupGracePeriod=const Duration(milliseconds:10);
    OrbitConnectivityNavigatorObserver.confirmationDelay=const Duration(milliseconds:10);
  });

  tearDown(() {
    observer.resetSessionState();
    OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;
    OrbitConnectionProbe.reset();
    OrbitConnectivityNavigatorObserver.startupGracePeriod=const Duration(seconds:8);
    OrbitConnectivityNavigatorObserver.confirmationDelay=const Duration(seconds:2);
    OrbitConnectivityNavigatorObserver.pollInterval=const Duration(seconds:12);
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    OrbitConnectivityNavigatorObserver.startMonitoringAfterStartup();
    await tester.pump(const Duration(milliseconds:20));
    await tester.pump(const Duration(milliseconds:20));
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    OrbitConnectivityNavigatorObserver.startMonitoringAfterStartup();
    await tester.pump(const Duration(milliseconds:20));
    await tester.pump(const Duration(milliseconds:20));
    await tester.pumpAndSettle();

    expect(find.text('Online Screen'), findsOneWidget);
    expect(find.text('You’re Offline'), findsNothing);
  });
  testWidgets('camera capture never opens global offline dialog and stale background probes are ignored',(tester)async{
    final pending=Completer<bool>();
    var probes=0;
    OrbitConnectionProbe.check=()async{probes++;return probes==1?await pending.future:false;};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(navigatorObservers:[observer],
      home:const Scaffold(body:Text('Camera preview'))));
    OrbitConnectivityNavigatorObserver.startMonitoringAfterStartup();
    await tester.pump(const Duration(milliseconds:20));
    expect(probes,1);
    OrbitConnectivityNavigatorObserver.enterLocalCapture();
    try{
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete(false);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds:4));
      await observer.checkNow();
      expect(find.text('You’re Offline'),findsNothing);
      expect(probes,1);
    }finally{
      OrbitConnectivityNavigatorObserver.leaveLocalCapture();
    }
    await tester.pump(const Duration(seconds:3));
    await tester.pump(const Duration(milliseconds:20));
    await tester.pumpAndSettle();
    expect(find.text('You’re Offline'),findsOneWidget);
    observer.resetSessionState();
  });
}
