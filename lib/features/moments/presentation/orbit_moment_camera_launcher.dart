import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/popups/orbit_popup_variants.dart';
import 'orbit_camera_permission_memory.dart';
import 'screens/moment_camera_screen.dart';

/// Central launcher for the global Orbit bottom-bar Add action.
///
/// The custom Orbit camera education popup is shown only until the camera has
/// successfully initialized once. After that, future Add taps go straight to
/// the existing MomentCameraScreen.
///
/// If the user never grants camera access, or camera initialization never
/// succeeds, the education popup is not permanently skipped.
abstract final class OrbitMomentCameraLauncher {
  static void open(BuildContext context) {
    unawaited(_open(context));
  }

  static Future<void> _open(BuildContext context) async {
    final alreadyConfirmed =
        await OrbitCameraPermissionMemory.hasConfirmedCameraAccess();

    if (!context.mounted) {
      return;
    }

    if (alreadyConfirmed) {
      _pushCamera(context);
      return;
    }

    await showCameraPermissionPopup(
      context,
      onAllow: () {
        if (!context.mounted) {
          return;
        }
        _pushCamera(context);
      },
      onNotNow: () {},
    );
  }

  static void _pushCamera(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MomentCameraScreen()),
    );
  }
}
