import 'package:flutter/foundation.dart';

@immutable
class PrivacySettings {
  const PrivacySettings({
    required this.locationVisibility,
    required this.locationActivity,
    required this.locationSharingEnabled,
    required this.ghostModeEnabled,
  });

  static const demo = PrivacySettings(
    locationVisibility: 'My Circle',
    locationActivity: 'abcfg..',
    locationSharingEnabled: true,
    ghostModeEnabled: true,
  );

  final String locationVisibility;
  final String locationActivity;
  final bool locationSharingEnabled;
  final bool ghostModeEnabled;

  PrivacySettings copyWith({
    String? locationVisibility,
    String? locationActivity,
    bool? locationSharingEnabled,
    bool? ghostModeEnabled,
  }) {
    return PrivacySettings(
      locationVisibility: locationVisibility ?? this.locationVisibility,
      locationActivity: locationActivity ?? this.locationActivity,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      ghostModeEnabled: ghostModeEnabled ?? this.ghostModeEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrivacySettings &&
            other.locationVisibility == locationVisibility &&
            other.locationActivity == locationActivity &&
            other.locationSharingEnabled == locationSharingEnabled &&
            other.ghostModeEnabled == ghostModeEnabled;
  }

  @override
  int get hashCode => Object.hash(
    locationVisibility,
    locationActivity,
    locationSharingEnabled,
    ghostModeEnabled,
  );
}
