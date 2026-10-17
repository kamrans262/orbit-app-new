import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/app_update/presentation/orbit_update_runtime.dart';
import 'features/connectivity/presentation/orbit_connectivity_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OrbitConnectivityNavigatorObserver.autoMonitorEnabled = true;
  OrbitUpdateNavigatorObserver.autoCheckEnabled = true;
  runApp(const OrbitApp());
}
