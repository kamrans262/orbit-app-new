import 'package:flutter/foundation.dart';

@immutable
class PrivacySettings {
  const PrivacySettings({
    required this.locationVisibility,
    required this.locationActivity,
    required this.locationSharingEnabled,
    required this.ghostModeEnabled,
    this.presenceVisibility = 'Nobody',
    this.activityVisibility = 'Nobody',
    this.pingEligibility = 'Nobody',
    this.messageEligibility = 'Nobody',
    this.momentDefaultAudience = 'Nobody',
    this.readReceiptsEnabled = false,
  });

  // Only for UI previews: the authenticated product always loads server policy.
  static const demo = PrivacySettings(
    locationVisibility: 'My Circle',
    locationActivity: 'Off',
    locationSharingEnabled: false,
    ghostModeEnabled: true,
  );

  static const safeDefaults = PrivacySettings(
    locationVisibility: 'Nobody',
    locationActivity: 'Off',
    locationSharingEnabled: false,
    ghostModeEnabled: true,
  );

  final String locationVisibility;
  final String locationActivity;
  final bool locationSharingEnabled;
  final bool ghostModeEnabled;
  final String presenceVisibility;
  final String activityVisibility;
  final String pingEligibility;
  final String messageEligibility;
  final String momentDefaultAudience;
  final bool readReceiptsEnabled;

  PrivacySettings copyWith({
    String? locationVisibility,
    String? locationActivity,
    bool? locationSharingEnabled,
    bool? ghostModeEnabled,
    String? presenceVisibility,
    String? activityVisibility,
    String? pingEligibility,
    String? messageEligibility,
    String? momentDefaultAudience,
    bool? readReceiptsEnabled,
  }) => PrivacySettings(
      locationVisibility: locationVisibility ?? this.locationVisibility,
      locationActivity: locationActivity ?? this.locationActivity,
      locationSharingEnabled: locationSharingEnabled ?? this.locationSharingEnabled,
      ghostModeEnabled: ghostModeEnabled ?? this.ghostModeEnabled,
      presenceVisibility: presenceVisibility ?? this.presenceVisibility,
      activityVisibility: activityVisibility ?? this.activityVisibility,
      pingEligibility: pingEligibility ?? this.pingEligibility,
      messageEligibility: messageEligibility ?? this.messageEligibility,
      momentDefaultAudience: momentDefaultAudience ?? this.momentDefaultAudience,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacySettings &&
          other.locationVisibility == locationVisibility &&
          other.locationActivity == locationActivity &&
          other.locationSharingEnabled == locationSharingEnabled &&
          other.ghostModeEnabled == ghostModeEnabled &&
          other.presenceVisibility == presenceVisibility &&
          other.activityVisibility == activityVisibility &&
          other.pingEligibility == pingEligibility &&
          other.messageEligibility == messageEligibility &&
          other.momentDefaultAudience == momentDefaultAudience &&
          other.readReceiptsEnabled == readReceiptsEnabled;

  @override
  int get hashCode => Object.hash(
        locationVisibility, locationActivity, locationSharingEnabled,
        ghostModeEnabled, presenceVisibility, activityVisibility, pingEligibility,
        messageEligibility, momentDefaultAudience, readReceiptsEnabled,
      );
}
