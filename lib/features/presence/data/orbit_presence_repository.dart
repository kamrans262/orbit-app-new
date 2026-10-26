import '../../auth/data/orbit_identity_client.dart';
import 'orbit_presence_models.dart';

/// No persistent cache or local inferred last-seen history.
class OrbitPresenceRepository {
  OrbitPresenceRepository({OrbitIdentityClient? identity,
    Future<Map<String, dynamic>> Function(String method, String path,
      {Map<String, Object?>? body})? request})
      : _request = request ?? (identity ?? OrbitIdentityClient.instance).socialRequest;

  final Future<Map<String, dynamic>> Function(String method, String path,
      {Map<String, Object?>? body}) _request;

  Future<Map<String, dynamic>> _data(String method, String path,
      {Map<String, Object?>? body}) async {
    final result = await _request(method,path,body:body);
    final data = result['data'];
    if (data is! Map) throw const FormatException('Invalid Presence API response.');
    return Map<String,dynamic>.from(data);
  }

  String _id(String value) {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value)) {
      throw const FormatException('Invalid Circle identifier.');
    }
    return Uri.encodeComponent(value);
  }

  Future<OrbitPresenceSnapshot> circle(String id, {DateTime? now}) async =>
    OrbitPresenceSnapshot.fromJson(await _data('GET','/circles/${_id(id)}/presence'),
      now:now);

  Future<OrbitPresencePreferences> preferences() async =>
    OrbitPresencePreferences.fromJson(await _data('GET','/me/presence/settings'));

  Future<void> heartbeat(String state) async {
    if (state != 'active' && state != 'idle') {
      throw ArgumentError.value(state, 'state');
    }
    await _data('POST','/presence/heartbeat',body:{'state':state});
  }

  Future<void> disconnect() async {
    await _data('POST','/presence/disconnect');
  }

  Future<void> circleConsent(String circleId,
      {required bool enabled, String? duration, DateTime? expiresAt}) async {
    if (enabled && duration != 'persistent' && duration != 'until_expiry') {
      throw const FormatException('Choose a Presence sharing duration.');
    }
    if (enabled && duration == 'until_expiry' &&
        (expiresAt == null || !expiresAt.isAfter(DateTime.now()))) {
      throw const FormatException('Choose a future expiry date.');
    }
    await _data('PUT','/me/presence/circles/${_id(circleId)}',body:{
      'enabled': enabled,
      if (enabled) 'duration':duration,
      if (enabled && duration == 'until_expiry')
        'expires_at':expiresAt!.toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> ticket() => _data('POST','/presence/realtime/ticket');

  Future<void> typing(String circleId, bool typing) async {
    await _data('POST','/circles/${_id(circleId)}/typing',body:{'typing':typing});
  }
}
