import '../../../features/auth/data/orbit_identity_client.dart';
import '../../../features/profile/data/orbit_profile_settings_repository.dart';
import '../../../features/profile/domain/models/notification_settings.dart';

/// Short-lived, account-scoped notification preferences. Fail closed when the
/// preference cannot be verified: never override an opt-out from a stale value.
/// Manually opened Ping history and the authenticated send API are unaffected.
class OrbitPingNotificationPreferences {
  OrbitPingNotificationPreferences._();
  static final OrbitPingNotificationPreferences instance =
      OrbitPingNotificationPreferences._();

  final OrbitIdentityClient _identity=OrbitIdentityClient.instance;
  final OrbitProfileSettingsRepository _settings=OrbitProfileSettingsRepository();
  String? _owner;
  NotificationSettings? _cached;
  DateTime? _checkedAt;

  Future<NotificationSettings?> _load() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null || owner.isEmpty) {
      _owner=null;
      _cached=null;
      _checkedAt=null;
      return null;
    }
    if(owner!=_owner) {
      _owner=owner;
      _cached=null;
      _checkedAt=null;
    }
    final last=_checkedAt;
    if(last!=null && _cached!=null &&
        DateTime.now().difference(last)<const Duration(seconds:30)) {
      return _cached;
    }
    try {
      final latest=await _settings.loadNotifications();
      if(await _identity.currentLocalSocialOwner()!=owner)return null;
      _cached=latest;
      _checkedAt=DateTime.now();
      return latest;
    }catch(_) {
      _cached=null;
      _checkedAt=null;
      return null;
    }
  }

  Future<bool> alertsEnabled() async =>
    (await _load())?.pingNotificationsEnabled==true;

  Future<bool> hapticsEnabled() async {
    final value=await _load();
    return value?.pingNotificationsEnabled==true && value?.vibrationEnabled==true;
  }
}
