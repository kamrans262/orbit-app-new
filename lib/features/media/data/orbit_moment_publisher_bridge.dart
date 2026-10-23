import 'dart:typed_data';

import '../../moments/domain/models/moment_publish_models.dart';
import 'orbit_moment_media_stager.dart';

/// M7 must return a real server-issued Moment ID AND proof that all audience
/// key envelopes / policy grants were committed. A media ID is not a Moment ID.
class OrbitConfirmedMoment {
  const OrbitConfirmedMoment({
    required this.momentId, required this.audienceKeysConfirmed});
  final String momentId;
  final bool audienceKeysConfirmed;
}

typedef OrbitM7Commit = Future<OrbitConfirmedMoment> Function({
  required String mediaId,
  required Set<String> circleIds,
  required String caption,
});

typedef OrbitPhotoStage = Future<OrbitStagedPhoto> Function(
  Uint8List photoBytes,
  void Function(double fraction) onProgress,
);

/// Fits the EXISTING Orbit MomentPublisher callback. It never shows a new
/// popup/snackbar and cannot return success until an actual M7 server commit.
/// Stage 3 leaves this disconnected until M7 implements OrbitM7Commit.
class OrbitMomentPublisherBridge {
  const OrbitMomentPublisherBridge({
    required this.stageEncryptedPhoto,
    required this.commitActualMoment,
  });
  final OrbitPhotoStage stageEncryptedPhoto;
  final OrbitM7Commit commitActualMoment;

  MomentPublisher get publisher => publish;

  Future<MomentPublishReceipt> publish(MomentPublishRequest request,
      void Function(double fraction) onProgress) async {
    if (request.circleIds.isEmpty) {
      throw StateError('A real audience must be selected before publishing.');
    }
    final staged = await stageEncryptedPhoto(
        request.photoBytes, (fraction) => onProgress(fraction * 0.88));
    if (!staged.privateGrantConfirmed || !staged.thumbnailVerified) {
      throw StateError('Encrypted media has not been verified.');
    }
    onProgress(0.9);
    final receipt = await commitActualMoment(
      mediaId:staged.mediaId,
      circleIds:request.circleIds,
      caption:request.caption,
    );
    if (!receipt.audienceKeysConfirmed || receipt.momentId.trim().isEmpty) {
      throw StateError('Orbit has not confirmed Moment delivery.');
    }
    onProgress(1.0);
    return MomentPublishReceipt(momentId:receipt.momentId);
  }
}
