class OrbitPersonData {
  const OrbitPersonData({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.markerX,
    required this.markerY,
    this.isNew = false,
  });

  final String id;
  final String name;
  final String? imagePath;

  /// Relative map position in the 0..1 range.
  final double markerX;
  final double markerY;
  final bool isNew;
}

class OrbitGiftData {
  const OrbitGiftData({required this.id, required this.emoji, this.label});

  final String id;
  final String emoji;
  final String? label;
}
