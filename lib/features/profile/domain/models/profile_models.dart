import 'dart:typed_data';
enum ProfileViewState { loading, empty, error, populated }

class ProfileData {
  const ProfileData({
    required this.id,
    required this.name,
    required this.bio,
    required this.circleCount,
    required this.friendCount,
    required this.momentCount,
    required this.moments,
    this.imagePath,
    this.imageUrl,
    this.imageBytes,
  });

  final String id;
  final String name;
  final String bio;
  final int circleCount;
  final int friendCount;
  final int momentCount;
  final String? imagePath;
  final String? imageUrl;
  /// Owner-only M6 avatar decrypted in RAM, not a public URL.
  final Uint8List? imageBytes;
  final List<ProfileMomentData> moments;
}

class ProfileMomentData {
  const ProfileMomentData({
    required this.id,
    this.imagePath,
    this.imageUrl,
    this.likeCount,
    this.remainingCount,
    this.aspectRatio,
    this.imageBytes,
  });

  final String id;
  final String? imagePath;
  final String? imageUrl;
  final int? likeCount;
  final int? remainingCount;

  /// Optional display aspect ratio (width / height).
  ///
  /// API data can provide this when known. When null, the image widget is free
  /// to size itself from the source image's intrinsic dimensions.
  final double? aspectRatio;
  final Uint8List? imageBytes;
}
