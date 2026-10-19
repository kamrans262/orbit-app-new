import '../../../auth/data/orbit_identity_client.dart';
import '../domain/models/notification_settings.dart';
import '../domain/models/privacy_settings.dart';
import '../domain/models/profile_models.dart';

/// All account-owned profile and settings requests go through the existing
/// authenticated Orbit identity client, including refresh/revoke handling.
class OrbitProfileSettingsRepository {
  OrbitProfileSettingsRepository({OrbitIdentityClient? identity})
      : _identity = identity ?? OrbitIdentityClient.instance;

  final OrbitIdentityClient _identity;

  Future<Map<String, dynamic>> loadProfile() => _identity.profile();

  Future<void> saveProfile(String name, String username, {String? bio}) =>
      _identity.saveProfile(name, username, bio: bio);

  ProfileData fromProfile(Map<String, dynamic> data) {
    final name = (data['display_name'] as String?)?.trim();
    return ProfileData(
      id: data['id'] as String,
      name: name == null || name.isEmpty ? 'My Profile' : name,
      bio: data['bio'] as String? ?? '',
      imagePath: null,
      circleCount: 0, // Not yet connected to the Circles module.
      friendCount: 0, // Not yet connected to the Friends module.
      momentCount: 0, // Not yet connected to the Moments module.
      moments: const <ProfileMomentData>[],
    );
  }

  Future<NotificationSettings> loadNotifications() async =>
      notificationsFromJson(await _identity.notificationPreferences());

  Future<NotificationSettings> saveNotifications(NotificationSettings value) async =>
      notificationsFromJson(await _identity.saveNotificationPreferences(notificationsToJson(value)));

  Future<PrivacySettings> loadPrivacy() async =>
      privacyFromJson(await _identity.privacyPreferences());

  Future<PrivacySettings> savePrivacy(PrivacySettings value) async =>
      privacyFromJson(await _identity.savePrivacyPreferences(privacyToJson(value)));

  static NotificationSettings notificationsFromJson(Map<String, dynamic> data) =>
      NotificationSettings(
        pushNotificationsEnabled: data['push_notifications_enabled'] == true,
        pingNotificationsEnabled: data['ping_notifications_enabled'] == true,
        momentsNotificationsEnabled: data['moments_notifications_enabled'] == true,
        circleUpdatesEnabled: data['circle_updates_enabled'] == true,
        sosAlertsEnabled: data['sos_alerts_enabled'] == true,
        soundEnabled: data['sound_enabled'] == true,
        vibrationEnabled: data['vibration_enabled'] == true,
      );

  static Map<String, Object?> notificationsToJson(NotificationSettings s) =>
      <String, Object?>{
        'push_notifications_enabled': s.pushNotificationsEnabled,
        'ping_notifications_enabled': s.pingNotificationsEnabled,
        'moments_notifications_enabled': s.momentsNotificationsEnabled,
        'circle_updates_enabled': s.circleUpdatesEnabled,
        'sos_alerts_enabled': s.sosAlertsEnabled,
        'sound_enabled': s.soundEnabled,
        'vibration_enabled': s.vibrationEnabled,
      };

  static PrivacySettings privacyFromJson(Map<String, dynamic> data) =>
      PrivacySettings(
        locationVisibility: data['location_visibility'] as String? ?? 'Nobody',
        locationActivity: data['location_activity'] as String? ?? 'Off',
        locationSharingEnabled: data['location_sharing_enabled'] == true,
        ghostModeEnabled: data['ghost_mode_enabled'] != false,
      );

  static Map<String, Object?> privacyToJson(PrivacySettings s) =>
      <String, Object?>{
        'location_visibility': s.locationVisibility,
        'location_activity': s.locationActivity,
        'location_sharing_enabled': s.locationSharingEnabled,
        'ghost_mode_enabled': s.ghostModeEnabled,
      };
}
