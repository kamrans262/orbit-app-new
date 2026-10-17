import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/app_update/presentation/orbit_update_runtime.dart';
import 'features/connectivity/presentation/orbit_connectivity_runtime.dart';
import 'features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Do not show the Update Available popup automatically at startup.
  // It remains available manually from:
  // Profile -> Settings -> Orbit Menu -> What's New.
  OrbitUpdateNavigatorObserver.autoCheckEnabled = false;

  // Avoid showing connectivity UI over the splash.
  OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;

  runApp(
    OrbitSplashGate(
      displayDuration: const Duration(seconds: 2),
      fadeDuration: const Duration(milliseconds: 280),
      onSplashFinished: () {
        OrbitConnectivityNavigatorObserver.startMonitoringAfterStartup();
      },
      child: OrbitApp(),
    ),
  );
}
