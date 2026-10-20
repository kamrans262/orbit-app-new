import 'dart:convert';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_social_repository.dart';

/// Strictly read-only, minimal personally-identifying snapshot.
/// No tokens, blocks, location, presence, contact matches or permissions.
class OrbitFriendSnapshot {
  const OrbitFriendSnapshot({required this.people, required this.savedAt});
  final List<OrbitPerson> people;
  final DateTime savedAt;
  static const maxAge = Duration(minutes: 15);

  static String encode(String owner, List<OrbitPerson> people, DateTime at) =>
      jsonEncode({
        'v': 1, 'owner': owner, 'at': at.toUtc().toIso8601String(),
        'people': people.take(250).map((p) => {
          'id': p.id, 'display_name': p.name, 'username': p.username,
        }).toList(),
      });

  static OrbitFriendSnapshot? decode(String? raw, String owner, DateTime now) {
    if (raw == null || raw.length > 90000) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['v'] != 1 || data['owner'] != owner) return null;
      final stamp = DateTime.parse(data['at'] as String).toUtc();
      final age = now.toUtc().difference(stamp);
      if (age.isNegative || age > maxAge) return null;
      final rows = data['people'];
      if (rows is! List || rows.length > 250) return null;
      final people = rows.map((x) => OrbitPerson.fromJson(
        Map<String, dynamic>.from(x as Map))).toList(growable: false);
      return OrbitFriendSnapshot(people: people, savedAt: stamp);
    } catch (_) {
      return null;
    }
  }
}

class OrbitFriendSnapshotStore {
  OrbitFriendSnapshotStore({OrbitIdentityClient? identity})
      : _identity = identity ?? OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

  Future<void> save(List<OrbitPerson> people) async {
    final owner = await _identity.currentLocalSocialOwner();
    if (owner == null) return;
    await _identity.storeFriendsSnapshot(
        owner, OrbitFriendSnapshot.encode(owner, people, DateTime.now()));
  }

  Future<OrbitFriendSnapshot?> read() async {
    final owner = await _identity.currentLocalSocialOwner();
    if (owner == null) return null;
    final raw = await _identity.readFriendsSnapshot();
    return OrbitFriendSnapshot.decode(raw, owner, DateTime.now());
  }

  Future<void> clear() => _identity.clearFriendsSnapshot();
}
