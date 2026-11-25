import 'package:flutter/material.dart';
import 'package:orbit_ui/core/widgets/app_gradient_action_label.dart';
import '../../../location/data/orbit_location_repository.dart';
import '../../data/orbit_profile_settings_repository.dart';
import '../../domain/models/privacy_settings.dart';
import '../../../notifications/presentation/orbit_live_notification_settings_screen.dart';
import 'privacy_setting_screen.dart';

/// Keep older navigation entry points on the shared live notification screen.
/// This preserves the approved settings UI and includes M14 token registration.
class OrbitNotificationPreferencesScreen extends StatelessWidget {
  const OrbitNotificationPreferencesScreen({super.key, this.repository});
  final OrbitProfileSettingsRepository? repository;

  @override
  Widget build(BuildContext context) =>
      OrbitLiveNotificationSettingsScreen(repository: repository);
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

  Future<PrivacySettings> _savePrivacy(PrivacySettings next) async {
    final saved=await _repo.savePrivacy(next);
    if(saved.ghostModeEnabled||!saved.locationSharingEnabled||
       saved.locationActivity=='Off'||saved.locationVisibility=='Nobody') {
      // Global privacy is authoritative even if M10 is not yet deployed.
      // Best-effort further clears grants and encrypted latest GPS.
      try{await OrbitLocationRepository().stopAll();}catch(_){}
    }
    return saved;
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
        onSaveSettings: _savePrivacy,
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
              TextButton(onPressed: onRetry, child: const AppGradientActionLabel('Try again')),
            ])
          : const CircularProgressIndicator(),
    ),
  );
}
