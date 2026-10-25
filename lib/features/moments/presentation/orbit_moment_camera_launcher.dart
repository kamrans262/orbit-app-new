import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/popups/orbit_popup_variants.dart';
import 'orbit_camera_permission_memory.dart';
import 'screens/moment_camera_screen.dart';
import '../domain/models/moment_publish_models.dart';
import '../../media/data/orbit_moment_media_stager.dart';
import '../data/orbit_moment_repository.dart';
import '../data/orbit_m7_rollout.dart';

/// Central launcher for the global Orbit bottom-bar Add action.
///
/// The custom Orbit camera education popup is shown only until the camera has
/// successfully initialized once. After that, future Add taps go straight to
/// the existing MomentCameraScreen.
///
/// If the user never grants camera access, or camera initialization never
/// succeeds, the education popup is not permanently skipped.
abstract final class OrbitMomentCameraLauncher {
  /// Resolve actual, permitted recipients before opening the existing camera.
  /// If M7 is unavailable, preserve M6 private save without demo publishing.
  static void openLive(BuildContext context) {
    unawaited(() async {
      if(!OrbitM7Rollout.enabled){
        if(context.mounted)await _open(context,circles:const []);
        return;
      }
      final repo=OrbitMomentRepository();
      try {
        final options=await repo.audienceOptions();
        if(!context.mounted)return;
        await _open(context,publisher:repo.publish,
          circles:options.circles,friends:options.friends,
          privacy:options.privacy);
      }catch(_){
        if(context.mounted)await _open(context,circles:const []);
      }
    }());
  }

  static void open(BuildContext context, {
    MomentPublisher? confirmedPublisher,
    List<MomentAudienceCircle> circles = const [],
  }) {
    unawaited(_open(context, publisher: confirmedPublisher, circles: circles));
  }

  static Future<void> _open(BuildContext context, {
    MomentPublisher? publisher,
    required List<MomentAudienceCircle> circles,
    List<MomentAudienceCircle> friends=const [],
    String privacy='Nobody',
  }) async {
    final alreadyConfirmed =
        await OrbitCameraPermissionMemory.hasConfirmedCameraAccess();

    if (!context.mounted) {
      return;
    }

    if (alreadyConfirmed) {
      _pushCamera(context, publisher: publisher, circles: circles, friends:friends, privacy:privacy);
      return;
    }

    await showCameraPermissionPopup(
      context,
      onAllow: () {
        if (!context.mounted) {
          return;
        }
        _pushCamera(context, publisher: publisher, circles: circles, friends:friends, privacy:privacy);
      },
      onNotNow: () {},
    );
  }

  static void _pushCamera(BuildContext context, {
    MomentPublisher? publisher,
    required List<MomentAudienceCircle> circles,
    List<MomentAudienceCircle> friends=const [],
    String privacy='Nobody',
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => MomentCameraScreen(
        publishMoment: publisher,
        momentAudienceCircles: circles,
        momentAudienceFriends:friends,
        momentPrivacyAudience:privacy,
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
