import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/app_update/presentation/orbit_update_runtime.dart';
import 'features/connectivity/presentation/orbit_connectivity_runtime.dart';
import 'features/splash/presentation/screens/orbit_splash_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep app-wide monitors quiet while the launch artwork is on screen.
  // They are enabled immediately before the real Orbit app is revealed.
  OrbitUpdateNavigatorObserver.autoCheckEnabled = false;
  OrbitConnectivityNavigatorObserver.autoMonitorEnabled = false;

  runApp(
    OrbitSplashGate(
      displayDuration: const Duration(seconds: 2),
      fadeDuration: const Duration(milliseconds: 280),
      onSplashFinished: () {
        OrbitUpdateNavigatorObserver.autoCheckEnabled = true;
        OrbitConnectivityNavigatorObserver.autoMonitorEnabled = true;
      },
      child: OrbitApp(),
    ),
  );
}
