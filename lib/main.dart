import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/splash/domain/orbit_startup_resolver.dart';
import 'features/auth/data/orbit_identity_client.dart';
import 'core/navigation/orbit_bottom_add_coordinator.dart';
import 'features/app_update/presentation/orbit_update_runtime.dart';
import 'features/connectivity/presentation/orbit_connectivity_runtime.dart';
import 'features/create/presentation/screens/orbit_create_sheet.dart';
import 'features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // One source of truth for the shared bottom-navigation + button.
  // Wherever the shared bottom bar is visible, + opens the Create sheet.
  OrbitBottomAddCoordinator.configure(OrbitCreateSheet.open);

  // Do not show the Update Available popup automatically at startup.
  // It remains available manually from:
  // Profile -> Settings -> Orbit Menu -> What's New.
  OrbitUpdateNavigatorObserver.autoCheckEnabled = false;

  // Avoid showing connectivity UI over the splash.
  OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;

  // Resolve session and load available account basics while splash is visible.
  // No Welcome/Get Started route is built before this future completes.
  final preparedApp = OrbitStartupResolver(
    OrbitIdentityClient.instance,
  ).resolve().then((startup) => OrbitApp(
    initialRoute: startup.route,
    startupAuthenticated: startup.authenticated,
  ));

  runApp(
    OrbitSplashGate(
      displayDuration: const Duration(seconds: 2),
      fadeDuration: const Duration(milliseconds: 280),
      onSplashFinished: () {
        OrbitConnectivityNavigatorObserver.startMonitoringAfterStartup();
      },
      preparedChild: preparedApp,
      child: const OrbitApp(),
    ),
  );
}
