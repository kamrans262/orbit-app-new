class NearbyPerson {
  const NearbyPerson({
    this.id,
    required this.name,
    required this.distance,
    required this.imageAsset,
  });

  /// Stable identity for live invited friends; demo nearby entries omit it.
  final String? id;
  final String name;
  final String distance;
  final String imageAsset;

  static const List<NearbyPerson> demoPeople = <NearbyPerson>[
    NearbyPerson(
      name: 'Emma',
      distance: '2.1 km',
      imageAsset: 'assets/Emma.png',
    ),
    NearbyPerson(
      name: 'Mike',
      distance: '3.4 km',
      imageAsset: 'assets/Mike.png',
    ),
    NearbyPerson(
      name: 'Sophia',
      distance: '5.0 km',
      imageAsset: 'assets/Sophia.png',
    ),
  ];
}
