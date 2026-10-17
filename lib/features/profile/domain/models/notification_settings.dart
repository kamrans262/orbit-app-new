import 'package:flutter/foundation.dart';

@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.pushNotificationsEnabled,
    required this.pingNotificationsEnabled,
    required this.momentsNotificationsEnabled,
    required this.circleUpdatesEnabled,
    required this.sosAlertsEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  static const NotificationSettings demo = NotificationSettings(
    pushNotificationsEnabled: true,
    pingNotificationsEnabled: true,
    momentsNotificationsEnabled: true,
    circleUpdatesEnabled: true,
    sosAlertsEnabled: true,
    soundEnabled: false,
    vibrationEnabled: true,
  );

  final bool pushNotificationsEnabled;
  final bool pingNotificationsEnabled;
  final bool momentsNotificationsEnabled;
  final bool circleUpdatesEnabled;
  final bool sosAlertsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  NotificationSettings copyWith({
    bool? pushNotificationsEnabled,
    bool? pingNotificationsEnabled,
    bool? momentsNotificationsEnabled,
    bool? circleUpdatesEnabled,
    bool? sosAlertsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettings(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      pingNotificationsEnabled:
          pingNotificationsEnabled ?? this.pingNotificationsEnabled,
      momentsNotificationsEnabled:
          momentsNotificationsEnabled ?? this.momentsNotificationsEnabled,
      circleUpdatesEnabled: circleUpdatesEnabled ?? this.circleUpdatesEnabled,
      sosAlertsEnabled: sosAlertsEnabled ?? this.sosAlertsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}
