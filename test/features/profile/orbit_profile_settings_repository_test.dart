import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/data/orbit_profile_settings_repository.dart';
import 'package:orbit_ui/features/profile/domain/models/privacy_settings.dart';
import 'package:orbit_ui/features/profile/domain/models/notification_settings.dart';

void main() {
  final repo = OrbitProfileSettingsRepository();

  test('Authenticated profile mapping never displays fabricated users or counts', () {
    final profile = repo.fromProfile(<String, dynamic>{
      'id': '2d184c7a-4f2a-40f6-8c48-a1fab1213456',
      'display_name': 'Real User',
      'username': 'real.user',
      'bio': 'Private bio',
    });
    expect(profile.name, 'Real User');
    expect(profile.bio, 'Private bio');
    expect(profile.friendCount, 0);
    expect(profile.circleCount, 0);
    expect(profile.momentCount, 0);
    expect(profile.moments, isEmpty);
    expect(profile.imagePath, isNull);
  });

  test('Notification values round trip through backend JSON contract', () {
    const value = NotificationSettings(
      pushNotificationsEnabled: false,
      pingNotificationsEnabled: true,
      momentsNotificationsEnabled: false,
      circleUpdatesEnabled: true,
      sosAlertsEnabled: true,
      soundEnabled: false,
      vibrationEnabled: true,
    );
    final json = OrbitProfileSettingsRepository.notificationsToJson(value);
    final decoded = OrbitProfileSettingsRepository.notificationsFromJson(
      Map<String, dynamic>.from(json),
    );
    expect(decoded.pushNotificationsEnabled, false);
    expect(decoded.pingNotificationsEnabled, true);
    expect(decoded.circleUpdatesEnabled, true);
    expect(decoded.soundEnabled, false);
  });

  test('Privacy defaults do not reveal location', () {
    final empty = OrbitProfileSettingsRepository.privacyFromJson({});
    expect(empty.locationVisibility, 'Nobody');
    expect(empty.locationActivity, 'Off');
    expect(empty.locationSharingEnabled, false);
    expect(empty.ghostModeEnabled, true);
    const update = PrivacySettings(
      locationVisibility: 'Friends',
      locationActivity: 'While moving',
      locationSharingEnabled: false,
      ghostModeEnabled: true,
    );
    final roundTrip = OrbitProfileSettingsRepository.privacyFromJson(
      Map<String, dynamic>.from(
        OrbitProfileSettingsRepository.privacyToJson(update),
      ),
    );
    expect(roundTrip, update);
  });
}
