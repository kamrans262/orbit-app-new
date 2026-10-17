import 'dart:typed_data';

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
    required Iterable<String> circleIds,
    required this.caption,
  }) : circleIds = Set<String>.unmodifiable(circleIds);

  final Uint8List photoBytes;
  final Set<String> circleIds;
  final String caption;
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
