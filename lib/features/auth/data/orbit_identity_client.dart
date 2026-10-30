import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'orbit_offline_profile_snapshot.dart';
import '../../circles/data/orbit_m5_firebase_change_source.dart';
import '../../presence/presentation/orbit_presence_runtime.dart';
import '../../media/data/orbit_media_outbox.dart';
import '../../moments/data/orbit_moment_offline_cache.dart';
import '../../moments/data/orbit_moment_capture_vault.dart';
import '../../moments/data/orbit_moment_intent_vault.dart';
import '../../moments/data/orbit_m7_background_retry.dart';
import '../../moments/data/orbit_moment_audience_memory.dart';

enum OrbitRestoreState { signedOut, authenticated, deviceRegistration, deletionPending, offlineProfile }

class OrbitIdentityException implements Exception {
  OrbitIdentityException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}


/// M6 key-material view is allowed only after a fresh trusted-device API read.
/// Never persist the private key in app preferences, logs or an upload request.
class OrbitMediaTrustedDevice {
  const OrbitMediaTrustedDevice({
    required this.id, required this.publicKey, required this.privateKey,
  });
  final String id;
  final List<int> publicKey;
  final List<int> privateKey;
}

/// Only consumer credentials live here; admin authentication is independent.
class OrbitIdentityClient {
  OrbitIdentityClient({http.Client? client, FlutterSecureStorage? storage})
      : _http = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static final OrbitIdentityClient instance = OrbitIdentityClient();
  static const _origin = 'https://indigo-caribou-178970.hostingersite.com/api/v1';
  static const _refreshKey = 'orbit.identity.refresh.v1';
  static const _idKey = 'orbit.identity.installation.v1';
  static const _publicKey = 'orbit.identity.public_key.v1';
  static const _privateKey = 'orbit.identity.private_key.v1';
  static const _userIdKey = 'orbit.identity.user_id.v1';
  static const _profileCacheKey = 'orbit.profile.encrypted_cache.v1';
  static const _friendsCacheKey = 'orbit.social.friends_snapshot.v1';
  static const _launchedKey = 'orbit.app.has_launched.v1';
  static const _circlesCacheKey = 'orbit.circles.read_only_snapshot.v1';
  static const _dashboardSafeKey = 'orbit.dashboard.safe_shell.v1';

  final http.Client _http;
  final FlutterSecureStorage _storage;
  String? _access;
  Future<void>? _pendingRefresh;
  Map<String, dynamic>? _startupProfile;
  Map<String, dynamic>? _startupNotifications;
  Map<String, dynamic>? _startupPrivacy;

  /// Preserve first-run state independently of sign-out. Legacy signed-in
  /// installations already have a device installation ID.
  Future<bool> hasLaunchedBefore() async =>
      await _storage.read(key: _launchedKey) == 'true' ||
      await _storage.read(key: _idKey) != null ||
      await _storage.read(key: _userIdKey) != null ||
      await _storage.read(key: _refreshKey) != null;

  Future<void> markLaunched() async =>
      _storage.write(key: _launchedKey, value: 'true');

  /// Warm only currently implemented API resources; Home does not yet have
  /// a live summary endpoint. Optional settings failures must not log out a
  /// freshly verified session or block launch.
  Future<void> preloadStartupData() async {
    Future<Map<String, dynamic>?> optional(
      Future<Map<String, dynamic>> Function() load,
    ) async {
      try {
        return await load();
      } on OrbitIdentityException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403 ||
            error.statusCode == 409) {
          rethrow;
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait<Map<String, dynamic>?>([
      optional(profile),
      optional(notificationPreferences),
      optional(privacyPreferences),
    ]).timeout(const Duration(seconds: 8), onTimeout: () =>
      <Map<String, dynamic>?>[null, null, null]);
    _startupProfile = results[0];
    _startupNotifications = results[1];
    _startupPrivacy = results[2];
  }

  // Ephemeral sign-up draft. Never stored on disk, sent to analytics or logs.
  String? _pendingSignupName;
  String? _pendingSignupPassword;
  String? get pendingSignupName => _pendingSignupName;

  void beginStandardSignup(String name, String password) {
    _pendingSignupName = name.trim();
    _pendingSignupPassword = password;
  }

  void abandonStandardSignup() {
    _pendingSignupName = null;
    _pendingSignupPassword = null;
  }

  void finishStandardSignup() {
    // Called only after password enrollment (when supplied) and profile save.
    abandonStandardSignup();
  }

  Future<void> completePendingPasswordEnrollment() async {
    final value = _pendingSignupPassword;
    if (value == null) return;
    // Only a fresh OTP session on a trusted registered device can enroll it.
    await _send('POST', '/me/password', protected: true,
        body: <String, Object?>{'password': value});
    _pendingSignupPassword = null;
  }

  Future<void> requestPasswordCode(String recipient, String password) async {
    await _send('POST', '/auth/password/otp/request',
        body: <String, Object?>{
          'recipient': recipient.trim(),
          'password': password,
        });
  }

  Future<String> get installationId async {
    final old = await _storage.read(key: _idKey);
    if (old != null && old.isNotEmpty) return old;
    final id = const Uuid().v4();
    await _storage.write(key: _idKey, value: id);
    return id;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool protected = false,
    bool allowRetry = true,
    String? idempotencyKey,
  }) async {
    if (protected && _access == null) await refresh();
    final request = http.Request(method, Uri.parse('$_origin$path'))
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json';
    if (protected && _access != null) {
      request.headers['Authorization'] = 'Bearer $_access';
    }
    if (idempotencyKey != null) request.headers['Idempotency-Key'] = idempotencyKey;
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 20)),
      );
    } catch (_) {
      throw OrbitIdentityException('Unable to connect to Orbit. Check your internet connection.');
    }
    if (protected && response.statusCode == 401 && allowRetry) {
      _access = null;
      await refresh();
      return _send(method, path, body: body, protected: true, allowRetry: false,
        idempotencyKey: idempotencyKey);
    }
    Map<String, dynamic> json;
    try {
      final parsed = jsonDecode(response.body);
      json = parsed is Map ? Map<String, dynamic>.from(parsed) : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OrbitIdentityException(
        json['message'] is String ? json['message'] as String : 'Orbit could not process this request.',
        response.statusCode,
      );
    }
    return json;
  }

  Future<void> requestCode(String channel, String recipient,
      {String purpose = 'signup'}) async {
    await _send('POST', '/auth/otp/request', body: <String, Object?>{
      'channel': channel, 'recipient': recipient.trim(), 'purpose': purpose,
    });
  }

  Future<void> requestPasswordResetCode(String recipient) async {
    await _send('POST', '/auth/password/reset/request',
        body: <String, Object?>{'recipient': recipient.trim()});
  }

  Future<void> confirmPasswordReset(String recipient, String code, String password) async {
    await _send('POST', '/auth/password/reset/confirm',
        body: <String, Object?>{
          'recipient': recipient.trim(), 'code': code.trim(), 'password': password,
        });
  }

  Future<void> verifyCode(String channel, String recipient, String code,
      {String purpose = 'signup'}) async {
    final result = await _send('POST', '/auth/otp/verify', body: <String, Object?>{
      'channel': channel, 'recipient': recipient.trim(), 'code': code.trim(),
      'purpose': purpose,
      'device_public_id': await installationId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'device_name': Platform.isIOS ? 'My iPhone' : 'My Android',
    });
    await _storeTokens(Map<String, dynamic>.from(result['data'] as Map));
  }

  Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    final access = tokens['access_token'];
    final refreshToken = tokens['refresh_token'];
    if (access is! String || refreshToken is! String) {
      throw OrbitIdentityException('Invalid session response.');
    }
    final user = tokens['user'];
    if (user is Map && user['id'] is String) {
      final nextUser = user['id'] as String;
      final lastUser = await _storage.read(key: _userIdKey);
      if (lastUser != nextUser) {
        if(lastUser != null && lastUser.isNotEmpty) {
          try { await OrbitMediaOutbox().purge(lastUser); }
          catch (_) { /* Block cross-account access even if disk cleanup fails. */ }
          try { await OrbitMomentOfflineCache().purge(lastUser); }
          catch (_) { /* Never transfer stale offline previews to another user. */ }
          try { await OrbitMomentCaptureVault().purge(lastUser); }catch(_){}
          try { await OrbitMomentIntentVault().purge(lastUser); }catch(_){}
          try { await OrbitMomentAudienceMemory().purge(lastUser); }catch(_){}
        }
        await OrbitPresenceRuntime.instance.stop();
        await OrbitM5FirebaseChangeSource.instance.stop();
        _startupProfile = null;
        _startupNotifications = null;
        _startupPrivacy = null;
        await _storage.delete(key: _profileCacheKey);
        await _storage.delete(key: _friendsCacheKey);
        if(lastUser != null && lastUser.isNotEmpty) {
          await _storage.delete(key: 'orbit.ping.pending.v1.$lastUser');
          await _storage.delete(key: 'orbit.ping.replykeys.v1.$lastUser');
          await _storage.delete(key: 'orbit.checkin.pending.v1.$lastUser');
          await _storage.delete(key: 'orbit.checkin.audience.v1.$lastUser');
        }
    await _storage.delete(key: _circlesCacheKey);
    await _storage.delete(key: _dashboardSafeKey);
      }
      await _storage.write(key: _userIdKey, value: nextUser);
    }
    await _storage.write(key: _refreshKey, value: refreshToken);
    _access = access;
  }

  Future<void> refresh() async {
    if (_pendingRefresh != null) return _pendingRefresh;
    final current = _refreshCore();
    _pendingRefresh = current;
    try {
      await current;
    } finally {
      _pendingRefresh = null;
    }
  }

  Future<void> _refreshCore() async {
    final token = await _storage.read(key: _refreshKey);
    if (token == null) throw OrbitIdentityException('Please sign in.', 401);
    try {
      final response = await _send('POST', '/auth/refresh',
          body: <String, Object?>{'refresh_token': token});
      await _storeTokens(Map<String, dynamic>.from(response['data'] as Map));
    } on OrbitIdentityException catch (error) {
      if (error.statusCode == 401) await clearSession();
      rethrow;
    }
  }

  /// Validate the server session, including trust and registration state, at boot.
  /// An expired or revoked token cannot take the user to the authenticated home.
  Future<OrbitRestoreState> restoreSession() async {
    try {
      final token = await _storage.read(key: _refreshKey);
      if (token == null || token.isEmpty) return OrbitRestoreState.signedOut;
      await refresh();
      await currentUser();
      return OrbitRestoreState.authenticated;
    } on OrbitIdentityException catch (error) {
      if (error.statusCode == 403) {
        return OrbitRestoreState.deviceRegistration;
      }
      if (error.statusCode == 409 && error.message.contains('pending deletion')) {
        return OrbitRestoreState.deletionPending;
      }
      if (error.statusCode == 401) {
        await clearSession();
        return OrbitRestoreState.signedOut;
      }
      // Server denial (403/409/422) must never grant any offline access.
      // Only network failures or temporary 5xx may show the one-hour,
      // read-only cached profile; never unlock the authenticated Home.
      if (error.statusCode == null || error.statusCode! >= 500) {
        // Keep the refresh token. The offline screen offers retry even when
        // there is no eligible encrypted profile snapshot to show.
        return OrbitRestoreState.offlineProfile;
      }
      return OrbitRestoreState.signedOut;
    } catch (_) {
      // Storage failures or malformed cache never unlock Home.
      return OrbitRestoreState.signedOut;
    }
  }

  Future<List<Map<String, dynamic>>> sessions() async {
    final response = await _send('GET', '/me/sessions', protected: true);
    return (response['data'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> revokeSession(String id) async {
    await _send('DELETE', '/me/sessions/$id', protected: true);
  }

  Future<void> signOutAll() async {
    try {
      await _send('POST', '/auth/logout-all', body: <String, Object?>{},
          protected: true);
    } finally {
      await clearSession();
    }
  }

  /// Submit a server-side privacy erasure request. The backend acknowledges a
  /// request, not final deletion, so the user-facing copy must reflect that.
  Future<void> requestDeletion() async {
    await _send('POST', '/me/deletion-request',
        body: <String, Object?>{'confirm': true}, protected: true);
    await clearSession();
  }

  Future<Map<String, dynamic>> deletionStatus() async {
    final result = await _send('GET', '/me/deletion-status', protected: true);
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<void> cancelDeletion() async {
    await _send('POST', '/me/deletion-cancel', protected: true,
        body: <String, Object?>{'confirm': true});
  }

  Future<void> clearSession() async {
    final oldMediaOwner=await _storage.read(key:_userIdKey);
    await OrbitM5FirebaseChangeSource.instance.stop();
    if(oldMediaOwner != null && oldMediaOwner.isNotEmpty) {
      try { await OrbitMediaOutbox().purge(oldMediaOwner); }
      catch (_) { /* Session revocation proceeds even if storage is unavailable. */ }
      try { await OrbitMomentOfflineCache().purge(oldMediaOwner); }
      catch (_) { /* Local secure read keys are best-effort purged on logout. */ }
      try { await OrbitMomentCaptureVault().purge(oldMediaOwner); }catch(_){}
      try { await OrbitMomentIntentVault().purge(oldMediaOwner); }catch(_){}
      await OrbitM7BackgroundRetry.cancel();
      try { await OrbitMomentAudienceMemory().purge(oldMediaOwner); }catch(_){}
    }
    abandonStandardSignup();
    _access = null;
    _startupProfile = null;
    _startupNotifications = null;
    _startupPrivacy = null;
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _profileCacheKey);
    await _storage.delete(key: _friendsCacheKey);
    if(oldMediaOwner != null && oldMediaOwner.isNotEmpty) {
      await _storage.delete(key: 'orbit.ping.pending.v1.$oldMediaOwner');
      await _storage.delete(key: 'orbit.ping.replykeys.v1.$oldMediaOwner');
      await _storage.delete(key: 'orbit.checkin.pending.v1.$oldMediaOwner');
      await _storage.delete(key: 'orbit.checkin.audience.v1.$oldMediaOwner');
    }
    await _storage.delete(key: _circlesCacheKey);
    await _storage.delete(key: _dashboardSafeKey);
  }

  Future<void> signOut() async {
    try {
      await _send('POST', '/auth/logout', body: <String, Object?>{}, protected: true);
    } finally {
      await clearSession();
    }
  }


  Future<OrbitMediaTrustedDevice> trustedMediaDevice() async {
    final owner=await currentLocalSocialOwner();
    if(owner==null)throw OrbitIdentityException('Sign in before accessing encrypted media.',401);
    // Always validate the live server trust state. An offline profile or stale
    // cached device record can never authorize an encrypted media action.
    final live=await devices();
    Map<String,dynamic>? active;
    for(final d in live){
      if(d['is_current']==true && d['trust_state']=='trusted' &&
         d['revoked_at']==null && d['key_registered']==true){
        active=d; break;
      }
    }
    if(active==null)throw OrbitIdentityException('Trusted device required.',403);
    final public=await _storage.read(key:_publicKey);
    final private=await _storage.read(key:_privateKey);
    if(public==null || private==null){
      throw OrbitIdentityException('Device encryption key is unavailable.',403);
    }
    late final List<int> pubBytes;
    late final List<int> privateBytes;
    try {
      pubBytes=base64Decode(public);
      privateBytes=base64Decode(private);
    } catch (_) {
      throw OrbitIdentityException('Device encryption key is invalid.',403);
    }
    if(pubBytes.length!=32 || privateBytes.length!=32){
      throw OrbitIdentityException('Device encryption key is invalid.',403);
    }
    return OrbitMediaTrustedDevice(id:active['id'] as String,
      publicKey:pubBytes,privateKey:privateBytes);
  }

  Future<bool> registerDevice() async {
    var publicKey = await _storage.read(key: _publicKey);
    if (publicKey == null) {
      final keys = await X25519().newKeyPair();
      final public = await keys.extractPublicKey();
      final private = await keys.extractPrivateKeyBytes();
      // Stored in OS-backed secure storage; non-exportable hardware keys are a later
      // security gate for launch E2EE, not claimed by this integration.
      await _storage.write(key: _privateKey, value: base64Encode(private));
      publicKey = base64Encode(public.bytes);
      await _storage.write(key: _publicKey, value: publicKey);
    }
    final response = await _send('POST', '/devices/register', protected: true,
        body: <String, Object?>{'public_key': publicKey});
    final record = Map<String, dynamic>.from(response['data'] as Map);
    if (record['trust_state'] == 'pending') {
      throw OrbitIdentityException(
        'Device registered. Waiting for approval from another trusted device.', 403);
    }
    return record['trust_state'] == 'trusted';
  }

  /// Two separate factors on a fresh pending-device session: account password
  /// and a new OTP bound to purpose device_recovery.
  Future<void> requestDeviceRecoveryCode(String recipient, String password) async {
    await _send('POST', '/devices/recovery/request', protected: true,
      body: <String, Object?>{
        'recipient': recipient.trim(),
        'password': password,
      });
  }

  Future<void> completeDeviceRecovery(
    String recipient, String password, String code,
  ) async {
    await _send('POST', '/devices/recovery/complete', protected: true,
      body: <String, Object?>{
        'recipient': recipient.trim(),
        'password': password,
        'code': code.trim(),
        'confirm_revoke_others': true,
      });
    // Never declare Home trusted until server reflects the state change.
    if (!await checkDeviceApproval()) {
      throw OrbitIdentityException('Device recovery could not be verified.');
    }
  }

  /// Pending devices may check their own status without access to account data.
  Future<bool> checkDeviceApproval() async {
    final response = await _send('GET', '/devices/registration-status',
        protected: true);
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return data['key_registered'] == true && data['trust_state'] == 'trusted';
  }

  /// Explicit, read-only offline preview. Requires an existing local session,
  /// matching user identity and a fresh OS-secure-storage snapshot.
  /// This does NOT verify current server-side trust or revocation.
  Future<Map<String, dynamic>?> cachedProfileForOffline() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    final owner = await _storage.read(key: _userIdKey);
    final encryptedJson = await _storage.read(key: _profileCacheKey);
    return OrbitOfflineProfileSnapshot.read(
      encryptedJson,
      owner: owner,
      sessionPresent: refreshToken != null && refreshToken.isNotEmpty,
      now: DateTime.now(),
    );
  }

  /// Profile-only encrypted cache, owned by the most recently verified user.
  /// Offline reads are clearly flagged; privacy and consent are never cached as
  /// authorization, and all writes must still reach the server.
  Future<Map<String, dynamic>> profile() async {
    final prefetched = _startupProfile;
    if (prefetched != null) {
      _startupProfile = null;
      return prefetched;
    }
    try {
      final result = await _send('GET', '/me/profile', protected: true);
      final data = Map<String, dynamic>.from(result['data'] as Map);
      final owner = await _storage.read(key: _userIdKey);
      if (owner != null && owner == data['id']) {
        // OS-backed secure storage, no credentials or sensitive preferences.
        await _storage.write(
          key: _profileCacheKey,
          value: OrbitOfflineProfileSnapshot.encode(data, DateTime.now()),
        );
      }
      return data;
    } on OrbitIdentityException catch (error) {
      // Device approval, deletion, suspension, logout or server rejection
      // cannot fall back to an offline "authorized" session.
      if (error.statusCode != null && error.statusCode! < 500) rethrow;
      final cached = await cachedProfileForOffline();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<Map<String, dynamic>> saveProfile(
    String name,
    String username, {
    String? bio,
    String? avatarMediaId,
  }) async {
    final result = await _send('PATCH', '/me/profile', protected: true,
        body: <String, Object?>{
          'display_name': name.trim(),
          'username': username.trim(),
          if (bio != null) 'bio': bio.trim(),
          if (avatarMediaId != null) 'avatar_media_id': avatarMediaId,
        });
    _startupProfile = null;
    await _storage.delete(key: _profileCacheKey);
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<Map<String, dynamic>> notificationPreferences() async {
    final prefetched = _startupNotifications;
    if (prefetched != null) {
      _startupNotifications = null;
      return prefetched;
    }
    final result = await _send('GET', '/me/preferences/notifications', protected: true);
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<Map<String, dynamic>> saveNotificationPreferences(
      Map<String, Object?> values) async {
    _startupNotifications = null;
    final result = await _send('PATCH', '/me/preferences/notifications',
        protected: true, body: values);
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<Map<String, dynamic>> privacyPreferences() async {
    final prefetched = _startupPrivacy;
    if (prefetched != null) {
      _startupPrivacy = null;
      return prefetched;
    }
    final result = await _send('GET', '/me/preferences/privacy', protected: true);
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<Map<String, dynamic>> savePrivacyPreferences(
      Map<String, Object?> values) async {
    _startupPrivacy = null;
    final result = await _send('PATCH', '/me/preferences/privacy',
        protected: true, body: values);
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  /// All M4 social requests share the verified Orbit bearer token, refresh,
  /// trust/deletion denial and 20-second timeout; no second HTTP stack.
  /// Owner-bound OS-secure-storage access. Only call after a verified,
  /// trusted, server-authorized Friends read. It cannot unlock offline Home.
  Future<String?> currentLocalSocialOwner() async {
    final token = await _storage.read(key: _refreshKey);
    if (token == null || token.isEmpty) return null;
    return _storage.read(key: _userIdKey);
  }

  Future<void> storeFriendsSnapshot(String owner, String payload) async {
    if (await currentLocalSocialOwner() != owner) return;
    await _storage.write(key: _friendsCacheKey, value: payload);
  }

  Future<String?> readFriendsSnapshot() async {
    if (await currentLocalSocialOwner() == null) return null;
    return _storage.read(key: _friendsCacheKey);
  }

  Future<void> clearFriendsSnapshot() => _storage.delete(key: _friendsCacheKey);

  /// OS-protected, account-bound SAFE SHELL; never a resource authorization.
  /// Only store the signed-in viewer's own name, never others or ciphertext.
  Future<void> storeDashboardSafeShell(String owner, String name) async {
    if (await currentLocalSocialOwner() != owner) return;
    await _storage.write(key: _dashboardSafeKey, value: jsonEncode({
      'owner':owner,'name':name,
      'saved_at':DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<String?> readDashboardSafeName() async {
    final owner=await currentLocalSocialOwner();
    if (owner==null) return null;
    final raw=await _storage.read(key:_dashboardSafeKey);
    if(raw==null) return null;
    try {
      final v=jsonDecode(raw);
      if(v is! Map || v['owner']!=owner || v['name'] is! String) return null;
      final saved=DateTime.tryParse(v['saved_at'] as String? ?? '');
      if(saved==null || saved.isAfter(DateTime.now()) ||
          DateTime.now().difference(saved)>const Duration(hours:24)) return null;
      return v['name'] as String;
    } catch (_) { return null; }
  }

  Future<void> clearDashboardSafeShell() =>
      _storage.delete(key:_dashboardSafeKey);

  /// M5 cached only sanitized Circle names and IDs, never membership lists,
  /// privacy grants, access tokens, location or invitation credentials.
  Future<void> storeCirclesSnapshot(String owner, String payload) async {
    if (await currentLocalSocialOwner() != owner) return;
    await _storage.write(key: _circlesCacheKey, value: payload);
  }

  Future<String?> readCirclesSnapshot() async {
    if (await currentLocalSocialOwner() == null) return null;
    return _storage.read(key: _circlesCacheKey);
  }

  Future<void> clearCirclesSnapshot() =>
      _storage.delete(key: _circlesCacheKey);


  /// Fetch/submit *only* binary ciphertext through the authenticated Orbit
  /// API. No refresh token, access token or media key is sent to an external
  /// storage URL. Bound to a maximum response to avoid device memory attacks.
  Future<Uint8List> mediaBinaryRequest(String method,String path,{
    Uint8List? body, Map<String,String> headers=const {},
    int maxResponseBytes=27*1024*1024, bool retry=true,
  }) async {
    if(!path.startsWith('/media/') || path.startsWith('//') ||
       path.contains('..') || path.contains('://') ||
       !['GET','PUT'].contains(method)) {
      throw ArgumentError.value(path,'path','Unsafe private-media API route');
    }
    if(_access==null)await refresh();
    final request=http.Request(method,Uri.parse('$_origin$path'));
    request.headers['Accept']='application/octet-stream';
    if(_access!=null)request.headers['Authorization']='Bearer $_access';
    request.headers.addAll(headers);
    if(body!=null) {
      if(body.length>1024*1024)throw ArgumentError('Private media chunk too large.');
      request.headers['Content-Type']='application/octet-stream';
      request.bodyBytes=body;
    }
    late final http.StreamedResponse response;
    try {
      response=await _http.send(request).timeout(const Duration(seconds:90));
    } catch (_) {
      throw OrbitIdentityException('Unable to transfer encrypted media.');
    }
    if(response.statusCode==401 && retry) {
      await response.stream.drain<void>();
      _access=null;
      await refresh();
      return mediaBinaryRequest(method,path,body:body,headers:headers,
          maxResponseBytes:maxResponseBytes,retry:false);
    }
    final buffered=BytesBuilder(copy:false);
    var total=0;
    try {
      await for(final chunk in response.stream.timeout(
          const Duration(seconds:90))) {
        total+=chunk.length;
        if(total>maxResponseBytes)throw OrbitIdentityException(
            'Encrypted media response exceeded safe limits.',413);
        buffered.add(chunk);
      }
    } catch (_) {
      throw OrbitIdentityException('Encrypted media transfer was interrupted.');
    }
    if(response.statusCode<200 || response.statusCode>=300) {
      throw OrbitIdentityException('Encrypted media transfer was denied.',
          response.statusCode);
    }
    return buffered.toBytes();
  }

  Future<Map<String, dynamic>> socialRequest(String method, String path,
      {Map<String, Object?>? body, String? idempotencyKey}) {
    if (!path.startsWith('/') || path.startsWith('//') ||
        path.contains('..') || path.contains('://')) {
      throw ArgumentError.value(path, 'path', 'Unsafe API path');
    }
    return _send(method, path, body: body, protected: true,
      idempotencyKey:idempotencyKey);
  }

  Future<Map<String, dynamic>> currentUser() =>
      _send('GET', '/me', protected: true);

  Future<void> linkIdentity(String channel, String recipient, String code) async {
    await _send('POST', '/me/identities/link', protected: true,
      body: <String, Object?>{
        'channel': channel,
        'recipient': recipient.trim(),
        'code': code.trim(),
      });
  }

  Future<void> updateProfileBasics(String displayName, String username, {String? bio}) async {
    await _send('PATCH', '/me/profile-basics', protected: true,
        body: <String, Object?>{
          'display_name': displayName.trim(),
          'username': username.trim(),
          if (bio != null) 'bio': bio.trim(),
        });
  }

  Future<List<Map<String, dynamic>>> devices() async {
    final response = await _send('GET', '/me/devices', protected: true);
    return (response['data'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> renameDevice(String id, String name) async {
    await _send('PATCH', '/me/devices/$id',
        protected: true, body: <String, Object?>{'name': name});
  }

  Future<void> revokeDevice(String id) async =>
      _send('DELETE', '/me/devices/$id', protected: true);

  Future<void> approveDevice(String id) async =>
      _send('POST', '/me/devices/$id/approve',
          protected: true, body: <String, Object?>{});
}
