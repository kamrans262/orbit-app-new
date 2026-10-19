import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_profile_settings_repository.dart';
import '../../domain/models/edit_profile_models.dart';
import '../../domain/models/profile_models.dart';
import 'edit_profile_screen.dart';
import 'orbit_preferences_screens.dart';
import 'profile_screen.dart';
import 'profile_settings_screen.dart';

/// The signed-in profile. Never use ProfileScreen.demo for account data.
class OrbitMyProfileScreen extends StatefulWidget {
  const OrbitMyProfileScreen({
    required this.onTabSelected,
    required this.onAddPressed,
    this.repository,
    super.key,
  });

  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final OrbitProfileSettingsRepository? repository;

  @override
  State<OrbitMyProfileScreen> createState() => _OrbitMyProfileScreenState();
}

class _OrbitMyProfileScreenState extends State<OrbitMyProfileScreen> {
  late final OrbitProfileSettingsRepository _repo =
      widget.repository ?? OrbitProfileSettingsRepository();
  late Future<Map<String, dynamic>> _profile = _repo.loadProfile();

  void _reload() {
    if (mounted) setState(() => _profile = _repo.loadProfile());
  }

  void _edit(BuildContext settingsContext, ProfileData profile, String username) {
    Navigator.of(settingsContext).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (editContext) => EditProfileScreen(
          profile: profile,
          initialFullName: profile.name,
          initialUsername: username,
          onBack: () => Navigator.of(editContext).pop(),
          onSave: (request) async {
            if (request.profileImageReference != null) {
              throw const EditProfileSaveException(
                message: 'Profile photo uploads are not enabled yet.');
            }
            try {
              await _repo.saveProfile(request.fullName, request.username);
            } on OrbitIdentityException catch (error) {
              throw EditProfileSaveException(
                message: error.message,
                usernameError: error.statusCode == 422
                    ? 'Please check this username for availability and format.'
                    : null,
              );
            }
            if (!editContext.mounted || !settingsContext.mounted) return;
            Navigator.of(editContext).pop();
            Navigator.of(settingsContext).pop();
            _reload();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('Could not load your profile.'),
                        TextButton(onPressed: _reload, child: const Text('Try again')),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final data = snapshot.data!;
        final profile = _repo.fromProfile(data);
        return ProfileScreen(
          isLiveAccount: true,
          profile: profile,
          onTabSelected: widget.onTabSelected,
          onAddPressed: widget.onAddPressed,
          onRetry: _reload,
          onSettingsClosed: _reload,
          settingsBuilder: (settingsContext) => SettingsScreen(
            profile: profile,
            onTabSelected: widget.onTabSelected,
            onAddPressed: widget.onAddPressed,
            onEditProfilePressed: () =>
                _edit(settingsContext, profile, data['username'] as String? ?? ''),
            onNotificationPressed: () {
              Navigator.of(settingsContext).push<void>(
                AppFadeSlidePageRoute<void>(
                  builder: (_) => const OrbitNotificationPreferencesScreen(),
                ),
              );
            },
            onPrivacySettingsPressed: () {
              Navigator.of(settingsContext).push<void>(
                AppFadeSlidePageRoute<void>(
                  builder: (_) => const OrbitPrivacyPreferencesScreen(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
