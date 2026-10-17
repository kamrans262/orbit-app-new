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
  });

  final String id;
  final String name;
  final String bio;
  final int circleCount;
  final int friendCount;
  final int momentCount;
  final String? imagePath;
  final String? imageUrl;
  final List<ProfileMomentData> moments;
}

class ProfileMomentData {
  const ProfileMomentData({
    required this.id,
    this.imagePath,
    this.imageUrl,
    this.likeCount,
    this.remainingCount,
  });

  final String id;
  final String? imagePath;
  final String? imageUrl;
  final int? likeCount;
  final int? remainingCount;
}
