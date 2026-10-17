import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/app_update/presentation/orbit_update_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OrbitUpdateNavigatorObserver.autoCheckEnabled = true;
  runApp(const OrbitApp());
}
