import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../media/data/orbit_media_repository.dart';
import '../domain/models/notification_settings.dart';
import '../domain/models/privacy_settings.dart';
import '../domain/models/profile_models.dart';

/// All account-owned profile and settings requests go through the existing
/// authenticated Orbit identity client, including refresh/revoke handling.
class OrbitProfileSettingsRepository {
  OrbitProfileSettingsRepository({
    OrbitIdentityClient? identity,
    OrbitMediaRepository? media,
    OrbitMediaCrypto? crypto,
  }) : _identity = identity ?? OrbitIdentityClient.instance,
       _media = media ?? OrbitMediaRepository(identity: identity),
       _crypto = crypto ?? OrbitMediaCrypto();

  final OrbitIdentityClient _identity;
  final OrbitMediaRepository _media;
  final OrbitMediaCrypto _crypto;

  Future<Map<String, dynamic>> loadProfile() async {
    final data=await _identity.profile();
    // The encrypted offline text snapshot never authorizes an avatar read.
    final id=data['avatar_media_id'];
    if(data['_offline_cached']!=true && id is String && id.isNotEmpty) {
      try {
        final device=await _identity.trustedMediaDevice();
        data['_avatar_bytes']=await _media.downloadPhoto(id,
          deviceId:device.id,privateKey:device.privateKey,
          publicKey:device.publicKey,
          maxPlainBytes:OrbitMediaFormat.imageLimit);
      } catch (_) {
        // No public URL fallback. A missing envelope / disabled media
        // cannot reveal or fabricate an owner's profile image.
      }
    }
    return data;
  }

  Future<void> saveProfile(String name, String username, {
    String? bio, String? avatarMediaId,
  }) async {
    await _identity.saveProfile(name,username,bio:bio,avatarMediaId:avatarMediaId);
  }

  /// Existing M6 AES-GCM transport. The server sees only ciphertext and an
  /// opaque reference. The source image's EXIF/GPS is stripped first.
  /// This first integration uses owner-only keys, NOT an open social avatar.
  Future<String> uploadAvatar(Uint8List photo) async {
    if(photo.isEmpty||photo.length>OrbitMediaFormat.imageLimit) {
      throw const FormatException('Invalid profile photo size.');
    }
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null)throw OrbitIdentityException('Sign in to change your photo.',401);
    final device=await _identity.trustedMediaDevice();
    final prepared=await compute(OrbitMediaCrypto.preparePhoto,photo);
    final transferId=const Uuid().v4();
    final dir=await getTemporaryDirectory();
    final file=File('${dir.path}/orbit-avatar-$transferId.cipher');
    try {
      // The 320px clean JPEG is ample for the approved 80px profile avatar.
      final sealed=await _crypto.sealBytes(prepared.thumbnail,
        destination:file,ownerId:owner,transferId:transferId,
        purpose:'avatar');
      final width=prepared.width<320?prepared.width:320;
      final height=(prepared.height*width/prepared.width).round();
      final receipt=await _media.upload(sealed,kind:'image',
        mime:'image/jpeg',width:width,height:height);
      if(!receipt.ready)throw StateError('Private avatar upload is still verifying.');
      final grants=await _media.createGrants(receipt.mediaId,
        audience:'only_me',recipients:const <String>[],
        idempotencyKey:transferId,
        keyEnvelopes:<Map<String,Object?>>[
          <String,Object?>{
            'device_id':device.id,'variant':'original',
            'key_version':'v1',
            'algorithm':OrbitMediaFormat.envelopeAlgorithm,
            'wrapped_key_ciphertext':await _crypto.wrapKey(sealed,device.publicKey),
          }
        ],
      );
      if(grants.isEmpty)throw StateError('Private avatar grant not confirmed.');
      return receipt.mediaId;
    } finally {
      if(await file.exists())await file.delete();
    }
  }

  ProfileData fromProfile(Map<String, dynamic> data) {
    final name = (data['display_name'] as String?)?.trim();
    return ProfileData(
      id: data['id'] as String,
      name: name == null || name.isEmpty ? 'My Profile' : name,
      bio: data['bio'] as String? ?? '',
      imagePath: null,
      imageBytes:data['_avatar_bytes'] is Uint8List ? data['_avatar_bytes'] as Uint8List : null,
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
        presenceVisibility: data['presence_visibility'] as String? ?? 'Nobody',
        activityVisibility: data['activity_visibility'] as String? ?? 'Nobody',
        pingEligibility: data['ping_eligibility'] as String? ?? 'Nobody',
        messageEligibility: data['message_eligibility'] as String? ?? 'Nobody',
        momentDefaultAudience: data['moment_default_audience'] as String? ?? 'Nobody',
        readReceiptsEnabled: data['read_receipts_enabled'] == true,
      );

  static Map<String, Object?> privacyToJson(PrivacySettings s) =>
      <String, Object?>{
        'location_visibility': s.locationVisibility,
        'location_activity': s.locationActivity,
        'location_sharing_enabled': s.locationSharingEnabled,
        'ghost_mode_enabled': s.ghostModeEnabled,
        'presence_visibility': s.presenceVisibility,
        'activity_visibility': s.activityVisibility,
        'ping_eligibility': s.pingEligibility,
        'message_eligibility': s.messageEligibility,
        'moment_default_audience': s.momentDefaultAudience,
        'read_receipts_enabled': s.readReceiptsEnabled,
      };
}
