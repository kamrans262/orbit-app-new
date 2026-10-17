class CircleSettings {
  const CircleSettings({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.colorValue,
    required this.liveLocationEnabled,
    required this.momentSharingEnabled,
    required this.pingEnabled,
    required this.sosAlertsEnabled,
  });

  final String id;
  final String name;
  final int memberCount;

  /// ARGB color value, intentionally stored as an integer so this model can be
  /// serialized directly without depending on Flutter's [Color] type.
  final int colorValue;
  final bool liveLocationEnabled;
  final bool momentSharingEnabled;
  final bool pingEnabled;
  final bool sosAlertsEnabled;

  CircleSettings copyWith({
    String? id,
    String? name,
    int? memberCount,
    int? colorValue,
    bool? liveLocationEnabled,
    bool? momentSharingEnabled,
    bool? pingEnabled,
    bool? sosAlertsEnabled,
  }) {
    return CircleSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      colorValue: colorValue ?? this.colorValue,
      liveLocationEnabled: liveLocationEnabled ?? this.liveLocationEnabled,
      momentSharingEnabled: momentSharingEnabled ?? this.momentSharingEnabled,
      pingEnabled: pingEnabled ?? this.pingEnabled,
      sosAlertsEnabled: sosAlertsEnabled ?? this.sosAlertsEnabled,
    );
  }
}

enum CircleSettingsViewState { loading, loaded, error }
