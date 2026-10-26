import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../media/data/orbit_media_crypto.dart';
import '../../data/orbit_profile_settings_repository.dart';
import '../../domain/models/edit_profile_models.dart';
import '../../domain/models/profile_models.dart';
import 'edit_profile_screen.dart';
import 'orbit_preferences_screens.dart';
import 'profile_screen.dart';
import 'orbit_live_profile_moments.dart';
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
    if (mounted) {
      setState(() {
        _profile = _repo.loadProfile();
      });
    }
  }

  void _edit(BuildContext settingsContext, ProfileData profile, String username) {
    Navigator.of(settingsContext).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (editContext) => EditProfileScreen(
          profile: profile,
          initialFullName: profile.name,
          initialUsername: username,
          initialBio: profile.bio,
          onBack: () => Navigator.of(editContext).pop(),
          onPickPhoto: (source) async {
            final picked=await ImagePicker().pickImage(
              source:source==EditProfilePhotoSource.camera
                  ? ImageSource.camera : ImageSource.gallery,
              maxWidth:1440,maxHeight:1440,imageQuality:85,
            );
            if(picked==null)return null;
            final bytes=await picked.readAsBytes();
            if(bytes.isEmpty||bytes.length>OrbitMediaFormat.imageLimit) {
              throw const FormatException('Photo must be smaller than 25 MB.');
            }
            return EditProfilePhotoSelection(
              previewImage:MemoryImage(Uint8List.fromList(bytes)),
              profilePhotoBytes:bytes,
            );
          },
          onSave: (request) async {
            try {
              String? avatarMediaId;
              if(request.profilePhotoBytes!=null) {
                avatarMediaId=await _repo.uploadAvatar(request.profilePhotoBytes!);
              }
              await _repo.saveProfile(request.fullName, request.username,
                  bio: request.bio, avatarMediaId:avatarMediaId);
            } on OrbitIdentityException catch (error) {
              throw EditProfileSaveException(
                message: error.message,
                usernameError: error.statusCode == 422
                    ? 'Please check this username for availability and format.'
                    : null,
              );
            } catch (_) {
              throw const EditProfileSaveException(
                message: 'Photo could not be saved. Check M6 Media on the server and retry.',
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
        final offline = data['_offline_cached'] == true;
        final profile = _repo.fromProfile(data);
        return Column(
          children: <Widget>[
            if (offline)
              const MaterialBanner(
                content: Text('Offline profile — last synced data. Editing requires a connection.'),
                actions: <Widget>[SizedBox.shrink()],
              ),
            Expanded(child: ProfileScreen(
          isLiveAccount: true,
          profile: profile,
          liveMomentsBuilder:(_)=>OrbitLiveProfileMoments(profileId:profile.id),
          onTabSelected: widget.onTabSelected,
          onAddPressed: widget.onAddPressed,
          onRetry: _reload,
          onSettingsClosed: _reload,
          settingsBuilder: (settingsContext) => SettingsScreen(
            profile: profile,
            onTabSelected: widget.onTabSelected,
            onAddPressed: widget.onAddPressed,
            onEditProfilePressed: () {
              if (offline) {
                ScaffoldMessenger.of(settingsContext).showSnackBar(const SnackBar(
                  content: Text('Reconnect before editing your profile.'),
                ));
                return;
              }
              _edit(settingsContext, profile, data['username'] as String? ?? '');
            },
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
            )),
          ],
        );
      },
    );
  }
}
