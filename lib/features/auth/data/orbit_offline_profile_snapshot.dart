import 'dart:convert';

/// Strictly scoped, encrypted-at-rest profile snapshot. Never use a cached
/// account to authorize Home, privacy, Circles, messaging, or other operations.
class OrbitOfflineProfileSnapshot {
  static const maxAge = Duration(hours: 1);

  static String encode(Map<String, dynamic> profile, DateTime now) => jsonEncode({
    'owner': profile['id'],
    'saved_at_ms': now.toUtc().millisecondsSinceEpoch,
    'profile': <String, dynamic>{
      'id': profile['id'],
      'display_name': profile['display_name'],
      'username': profile['username'],
      'bio': profile['bio'],
    },
  });

  static Map<String, dynamic>? read(
    String? value, {
    required String? owner,
    required bool sessionPresent,
    required DateTime now,
  }) {
    if (!sessionPresent || owner == null || owner.isEmpty ||
        value == null || value.length > 16384) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final record = Map<String, dynamic>.from(decoded);
      if (record['owner'] != owner || record['saved_at_ms'] is! int) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        record['saved_at_ms'] as int, isUtc: true);
      final elapsed = now.toUtc().difference(savedAt);
      if (elapsed.isNegative || elapsed > maxAge) return null;
      final data = Map<String, dynamic>.from(record['profile'] as Map);
      if (data['id'] != owner || data['display_name'] is! String ||
          data['username'] is! String && data['username'] != null ||
          data['bio'] is! String && data['bio'] != null) return null;
      return <String, dynamic>{
        'id': owner,
        'display_name': data['display_name'],
        'username': data['username'],
        'bio': data['bio'],
        '_offline_cached': true,
      };
    } catch (_) {
      return null;
    }
  }
}
