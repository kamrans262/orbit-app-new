import 'package:flutter/foundation.dart';

/// Server expiry is authoritative. Unknown means *not verified*, never offline.
@immutable
class OrbitPresenceMember {
  const OrbitPresenceMember({required this.userId, required this.state,
    required this.expiresAt, this.observedAt});
  final String userId;
  final String state;
  final DateTime expiresAt;
  final DateTime? observedAt;

  static OrbitPresenceMember fromJson(Map<String, dynamic> json) {
    final id = json['user_id'];
    final state = json['state'];
    final expires = DateTime.tryParse(json['expires_at'] as String? ?? '');
    if (id is! String || id.isEmpty || (state != 'active_now' && state != 'idle')
        || expires == null) {
      throw const FormatException('Invalid live Presence state.');
    }
    return OrbitPresenceMember(userId: id, state: state,
      expiresAt: expires.toUtc(),
      observedAt: DateTime.tryParse(json['observed_at'] as String? ?? '')?.toUtc());
  }

  bool validAt(DateTime now) => now.toUtc().isBefore(expiresAt);
  String? labelAt(DateTime now) {
    if (!validAt(now)) return null;
    if (state == 'active_now') return 'Active now';
    return 'Idle';
  }
}

@immutable
class OrbitPresenceSnapshot {
  const OrbitPresenceSnapshot({required this.circleId,
    required this.members, required this.receivedAt});
  final String circleId;
  final Map<String, OrbitPresenceMember> members;
  final DateTime receivedAt;
  static const maxReadAge = Duration(seconds: 30);

  static OrbitPresenceSnapshot fromJson(Map<String, dynamic> json,
      {DateTime? now}) {
    final id = json['circle_id'];
    final raw = json['members'];
    if (id is! String || id.isEmpty || raw is! List) {
      throw const FormatException('Invalid Presence snapshot.');
    }
    final members = <String, OrbitPresenceMember>{};
    final stamp = (now ?? DateTime.now()).toUtc();
    if (raw.length > 100) throw const FormatException('Oversized Presence roster.');
    for (final value in raw) {
      if (value is! Map) throw const FormatException('Invalid Presence member.');
      final person = OrbitPresenceMember.fromJson(Map<String, dynamic>.from(value));
      if (person.validAt(stamp)) members[person.userId] = person;
    }
    return OrbitPresenceSnapshot(circleId: id, members: Map.unmodifiable(members),
      receivedAt: stamp);
  }

  /// Never show data older than a bounded server-authorized response.
  OrbitPresenceMember? member(String id, DateTime now) {
    final current = now.toUtc();
    if (current.isBefore(receivedAt) ||
        current.difference(receivedAt) >= maxReadAge) return null;
    final value = members[id];
    return value != null && value.validAt(current) ? value : null;
  }
}

@immutable
class OrbitPresenceCircleConsent {
  const OrbitPresenceCircleConsent({required this.circleId,
    required this.requested, this.duration, this.expiresAt});
  final String circleId;
  final bool requested;
  final String? duration;
  final DateTime? expiresAt;
  bool get expired => expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  factory OrbitPresenceCircleConsent.fromJson(Map<String, dynamic> value) {
    final id = value['circle_id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid Presence consent.');
    }
    return OrbitPresenceCircleConsent(circleId:id, requested:value['requested']==true,
      duration:value['duration'] as String?,
      expiresAt:DateTime.tryParse(value['expires_at'] as String? ?? '')?.toUtc());
  }
}

@immutable
class OrbitPresencePreferences {
  const OrbitPresencePreferences({required this.ghostEnabled,
    required this.visibility, required this.circles});
  final bool ghostEnabled;
  final String visibility;
  final List<OrbitPresenceCircleConsent> circles;
  bool get globalPermitsPresence => !ghostEnabled && visibility == 'My Circle';

  factory OrbitPresencePreferences.fromJson(Map<String, dynamic> data) {
    final global = data['global'];
    if (global is! Map || data['circles'] is! List) {
      throw const FormatException('Invalid Presence preferences.');
    }
    final map = Map<String, dynamic>.from(global);
    return OrbitPresencePreferences(ghostEnabled:map['ghost_mode_enabled'] != false,
      visibility:map['presence_visibility'] as String? ?? 'Nobody',
      circles:(data['circles'] as List).map((e) =>
        OrbitPresenceCircleConsent.fromJson(Map<String, dynamic>.from(e as Map))).toList());
  }

  OrbitPresenceCircleConsent? forCircle(String id) {
    for (final item in circles) { if (item.circleId == id) return item; }
    return null;
  }
}
