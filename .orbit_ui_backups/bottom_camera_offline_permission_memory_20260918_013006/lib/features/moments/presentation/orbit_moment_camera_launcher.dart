import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/popups/orbit_popup_variants.dart';
import 'screens/moment_camera_screen.dart';

/// Central launcher for the global Orbit bottom-bar Add action.
///
/// It intentionally reuses the existing Camera Permission popup and existing
/// MomentCameraScreen so Home / Orbit / Profile do not create a second camera
/// flow or duplicate UI.
abstract final class OrbitMomentCameraLauncher {
  static void open(BuildContext context) {
    unawaited(
      showCameraPermissionPopup(
        context,
        onAllow: () {
          if (!context.mounted) {
            return;
          }

          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const MomentCameraScreen()),
          );
        },
        onNotNow: () {},
      ),
    );
  }
}
