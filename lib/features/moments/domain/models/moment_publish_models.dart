import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

/// A circle supplied by the membership repository, not inferred from contacts.
class MomentAudienceCircle {
  const MomentAudienceCircle({required this.id, required this.name});

  final String id;
  final String name;
}

/// Media and selected audience remain on the device until publish is invoked.
class MomentPublishRequest {
  MomentPublishRequest({
    required this.photoBytes,
    this.mediaFile,
    this.mediaKind='image',
    this.durationMs,
    this.muteVideo=false,
    this.waveformLevels=const [],
    this.placeLabel='',
    this.locationConsent=false,
    Iterable<String> taggedUserIds=const [],
    required Iterable<String> circleIds,
    required this.caption,
    this.audienceKind='selected_circles',
    Iterable<String>? targetIds,
    String? clientId,
  }) : taggedUserIds=Set<String>.unmodifiable(taggedUserIds),
       targetIds=Set<String>.unmodifiable(targetIds??circleIds),
       clientId=clientId??const Uuid().v4(), circleIds = Set<String>.unmodifiable(circleIds);

  final Uint8List photoBytes;
  final File? mediaFile;
  final String mediaKind;
  final int? durationMs;
  final bool muteVideo;
  final List<double> waveformLevels;
  final String placeLabel;
  final bool locationConsent;
  final Set<String> taggedUserIds;
  final Set<String> circleIds;
  final String caption;
  final String audienceKind;
  final Set<String> targetIds;
  final String clientId;
}

/// Only return this after the service confirms creation of the Moment.
class MomentPublishReceipt {
  const MomentPublishReceipt({required this.momentId});

  final String momentId;
}

/// Backend-facing contract. The callback reports 0..1 actual upload progress.
/// It must not return a receipt until the server acknowledges the Moment.
typedef MomentPublisher = Future<MomentPublishReceipt> Function(
  MomentPublishRequest request,
  void Function(double fraction) onProgress,
);
