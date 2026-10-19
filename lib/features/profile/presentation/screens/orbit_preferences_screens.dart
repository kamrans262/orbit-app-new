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
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  NotificationSettings? _current;

  void _retry() {
    setState(() {
      _future = _repo.loadNotifications();
    });
  }

  void _update(NotificationSettings next) {
    final revision = ++_revision;
    _writes = _writes.then((_) async {
      try {
        final saved = await _repo.saveNotifications(next);
        if (mounted && revision == _revision) setState(() => _current = saved);
      } catch (_) {
        if (!mounted || revision != _revision) return;
        try {
          final actual = await _repo.loadNotifications();
          if (mounted && revision == _revision) setState(() => _current = actual);
        } catch (_) {
          _retry();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save notification preferences. Please retry.'),
          ));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationSettings>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _LoadingSettings(error: snapshot.hasError, onRetry: _retry);
        }
        final current = _current ?? snapshot.data!;
        return NotificationScreen(
          initialSettings: current,
          onSettingsChanged: _update,
          onBack: () => Navigator.of(context).pop(),
        );
      },
    );
  }
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
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  PrivacySettings? _current;

  void _retry() {
    setState(() {
      _future = _repo.loadPrivacy();
    });
  }

  void _update(PrivacySettings next) {
    final revision = ++_revision;
    _writes = _writes.then((_) async {
      try {
        final saved = await _repo.savePrivacy(next);
        if (mounted && revision == _revision) setState(() => _current = saved);
      } catch (_) {
        if (!mounted || revision != _revision) return;
        try {
          final actual = await _repo.loadPrivacy();
          if (mounted && revision == _revision) setState(() => _current = actual);
        } catch (_) {
          _retry();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save privacy preferences. Please retry.'),
          ));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrivacySettings>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _LoadingSettings(error: snapshot.hasError, onRetry: _retry);
        }
        final current = _current ?? snapshot.data!;
        return PrivacySettingScreen(
          initialSettings: current,
          locationActivityOptions: const ['Active', 'While moving', 'Off'],
          onSettingsChanged: _update,
          onBack: () => Navigator.of(context).pop(),
        );
      },
    );
  }
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
