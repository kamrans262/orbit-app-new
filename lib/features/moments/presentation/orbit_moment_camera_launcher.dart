import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/popups/orbit_popup_variants.dart';
import 'orbit_camera_permission_memory.dart';
import 'screens/moment_camera_screen.dart';
import '../domain/models/moment_publish_models.dart';
import '../../media/data/orbit_moment_media_stager.dart';

/// Central launcher for the global Orbit bottom-bar Add action.
///
/// The custom Orbit camera education popup is shown only until the camera has
/// successfully initialized once. After that, future Add taps go straight to
/// the existing MomentCameraScreen.
///
/// If the user never grants camera access, or camera initialization never
/// succeeds, the education popup is not permanently skipped.
abstract final class OrbitMomentCameraLauncher {
  static void open(BuildContext context, {
    MomentPublisher? confirmedPublisher,
    List<MomentAudienceCircle> circles = const [],
  }) {
    unawaited(_open(context, publisher: confirmedPublisher, circles: circles));
  }

  static Future<void> _open(BuildContext context, {
    MomentPublisher? publisher,
    required List<MomentAudienceCircle> circles,
  }) async {
    final alreadyConfirmed =
        await OrbitCameraPermissionMemory.hasConfirmedCameraAccess();

    if (!context.mounted) {
      return;
    }

    if (alreadyConfirmed) {
      _pushCamera(context, publisher: publisher, circles: circles);
      return;
    }

    await showCameraPermissionPopup(
      context,
      onAllow: () {
        if (!context.mounted) {
          return;
        }
        _pushCamera(context, publisher: publisher, circles: circles);
      },
      onNotNow: () {},
    );
  }

  static void _pushCamera(BuildContext context, {
    MomentPublisher? publisher,
    required List<MomentAudienceCircle> circles,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => MomentCameraScreen(
        publishMoment: publisher,
        momentAudienceCircles: circles,
        privateSaver: (bytes, progress) async {
          final saved = await OrbitMomentMediaStager()
              .stagePhoto(bytes, onProgress: progress);
          if (!saved.thumbnailVerified || !saved.privateGrantConfirmed) {
            throw StateError('Private encrypted storage not confirmed.');
          }
        },
      )),
    );
  }
}
