import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/app_update/presentation/orbit_update_runtime.dart';
import 'features/connectivity/presentation/orbit_connectivity_runtime.dart';
import 'features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The automatic Update Available popup is intentionally disabled at app
  // startup. The same popup remains available manually from:
  // Profile -> Settings -> Orbit Menu -> What's New.
  OrbitUpdateNavigatorObserver.autoCheckEnabled = false;

  // Keep connectivity monitoring quiet while the launch artwork is visible.
  OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;

  runApp(
    OrbitSplashGate(
      displayDuration: const Duration(seconds: 2),
      fadeDuration: const Duration(milliseconds: 280),
      onSplashFinished: () {
        // Enable app-wide offline monitoring only after the splash completes.
        OrbitConnectivityNavigatorObserver.autoMonitorEnabled = true;
      },
      child: OrbitApp(),
    ),
  );
}
