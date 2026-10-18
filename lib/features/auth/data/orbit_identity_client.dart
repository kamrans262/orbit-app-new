import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class OrbitIdentityException implements Exception {
  OrbitIdentityException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
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

  final http.Client _http;
  final FlutterSecureStorage _storage;
  String? _access;
  Future<void>? _pendingRefresh;

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
  }) async {
    if (protected && _access == null) await refresh();
    final request = http.Request(method, Uri.parse('$_origin$path'))
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json';
    if (protected && _access != null) {
      request.headers['Authorization'] = 'Bearer $_access';
    }
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
      return _send(method, path, body: body, protected: true, allowRetry: false);
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

  Future<void> requestCode(String channel, String recipient) async {
    await _send('POST', '/auth/otp/request', body: <String, Object?>{
      'channel': channel, 'recipient': recipient.trim(),
    });
  }

  Future<void> verifyCode(String channel, String recipient, String code) async {
    final result = await _send('POST', '/auth/otp/verify', body: <String, Object?>{
      'channel': channel, 'recipient': recipient.trim(), 'code': code.trim(),
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

  Future<void> clearSession() async {
    _access = null;
    await _storage.delete(key: _refreshKey);
  }

  Future<void> signOut() async {
    try {
      await _send('POST', '/auth/logout', body: <String, Object?>{}, protected: true);
    } finally {
      await clearSession();
    }
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
    await _send('POST', '/devices/register', protected: true,
        body: <String, Object?>{'public_key': publicKey});
    return true;
  }

  Future<Map<String, dynamic>> currentUser() =>
      _send('GET', '/me', protected: true);

  Future<List<Map<String, dynamic>>> devices() async {
    final response = await _send('GET', '/me/devices', protected: true);
    return (response['data'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> revokeDevice(String id) async =>
      _send('DELETE', '/me/devices/$id', protected: true);

  Future<void> approveDevice(String id) async =>
      _send('POST', '/me/devices/$id/approve',
          protected: true, body: <String, Object?>{});
}
