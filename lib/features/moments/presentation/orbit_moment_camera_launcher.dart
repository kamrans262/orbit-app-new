import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/popups/orbit_popup_variants.dart';
import 'orbit_camera_permission_memory.dart';
import 'screens/moment_camera_screen.dart';
import '../domain/models/moment_publish_models.dart';
import '../../media/data/orbit_moment_media_stager.dart';
import '../../media/data/orbit_media_outbox.dart';
import '../../auth/data/orbit_identity_client.dart';
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
    // A single camera route owns one in-progress M6 private-save transfer.
    // Repeated Retry taps must resume its encrypted outbox, not enqueue and
    // upload another copy of the user's photo.
    final stager=OrbitMomentMediaStager();
    final outbox=OrbitMediaOutbox();
    String? queuedPrivateTransfer;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => MomentCameraScreen(
        publishMoment: publisher,
        momentAudienceCircles: circles,
        momentAudienceFriends:friends,
        momentPrivacyAudience:privacy,
        privateSaver: (bytes, progress) async {
          final pendingId=queuedPrivateTransfer;
          if(pendingId!=null){
            final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
            if(owner==null){
              throw OrbitIdentityException('Sign in to retry private media.',401);
            }
            final before=await outbox.pending(owner);
            if(before.any((media)=>media.transfer==pendingId)){
              await stager.retryPending(
                shouldRetry:(media)=>media.transfer==pendingId,
                onProgress:progress,
              );
              final after=await outbox.pending(owner);
              if(after.any((media)=>media.transfer==pendingId ||
                  media.parentTransferId==pendingId)){
                throw StateError('Encrypted private media is still pending verification.');
              }
              queuedPrivateTransfer=null;
              return;
            }
            // A completed outbox entry may already have been acknowledged
            // by the retry scheduler. Do not silently duplicate its upload.
            throw StateError('This private upload is no longer queued. '
              'Return to review and start a new save if needed.');
          }
          final saved=await stager.stagePhoto(bytes,
            onProgress:progress,
            onQueued:(transfer) async=>queuedPrivateTransfer=transfer);
          if(!saved.thumbnailVerified || !saved.privateGrantConfirmed){
            throw StateError('Private encrypted storage not confirmed.');
          }
          queuedPrivateTransfer=null;
        },
      )),
    );
  }
}
