import 'package:flutter/material.dart';

import '../../data/orbit_profile_settings_repository.dart';
import '../../domain/models/notification_settings.dart';
import '../../domain/models/privacy_settings.dart';
import 'notification_screen.dart';
import 'privacy_setting_screen.dart';

class OrbitNotificationPreferencesScreen extends StatefulWidget {
  const OrbitNotificationPreferencesScreen({super.key, this.repository});
  final OrbitProfileSettingsRepository? repository;

  @override
  State<OrbitNotificationPreferencesScreen> createState() =>
      _OrbitNotificationPreferencesScreenState();
}

class _OrbitNotificationPreferencesScreenState
    extends State<OrbitNotificationPreferencesScreen> {
  late final OrbitProfileSettingsRepository _repo =
      widget.repository ?? OrbitProfileSettingsRepository();
  late Future<NotificationSettings> _future = _repo.loadNotifications();

  void _retry() {
    setState(() {
      _future = _repo.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NotificationSettings>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return _LoadingSettings(error: snapshot.hasError, onRetry: _retry);
      }
      return NotificationScreen(
        initialSettings: snapshot.data!,
        onSaveSettings: _repo.saveNotifications,
        onBack: () => Navigator.of(context).pop(),
      );
    },
  );
}

class OrbitPrivacyPreferencesScreen extends StatefulWidget {
  const OrbitPrivacyPreferencesScreen({super.key, this.repository});
  final OrbitProfileSettingsRepository? repository;

  @override
  State<OrbitPrivacyPreferencesScreen> createState() =>
      _OrbitPrivacyPreferencesScreenState();
}

class _OrbitPrivacyPreferencesScreenState
    extends State<OrbitPrivacyPreferencesScreen> {
  late final OrbitProfileSettingsRepository _repo =
      widget.repository ?? OrbitProfileSettingsRepository();
  late Future<PrivacySettings> _future = _repo.loadPrivacy();

  void _retry() {
    setState(() {
      _future = _repo.loadPrivacy();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PrivacySettings>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return _LoadingSettings(error: snapshot.hasError, onRetry: _retry);
      }
      return PrivacySettingScreen(
        initialSettings: snapshot.data!,
        locationActivityOptions: const ['Active', 'While moving', 'Off'],
        onSaveSettings: _repo.savePrivacy,
        onBack: () => Navigator.of(context).pop(),
      );
    },
  );
}

class _LoadingSettings extends StatelessWidget {
  const _LoadingSettings({required this.error, required this.onRetry});
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: error
          ? Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('Could not load settings.'),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ])
          : const CircularProgressIndicator(),
    ),
  );
}
