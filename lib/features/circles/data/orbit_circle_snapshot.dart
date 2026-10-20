import 'dart:convert';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_circle_repository.dart';

/// Short-lived, owner-bound names-only display snapshot; no authorized offline
/// Circle mutations, roster access, invite codes, role details, or location.
class OrbitCircleSnapshot {
  const OrbitCircleSnapshot(this.circles, this.savedAt);
  final List<OrbitCircle> circles;
  final DateTime savedAt;
  static const ttl = Duration(minutes: 15);

  static String encode(String owner, List<OrbitCircle> items, DateTime now) =>
      jsonEncode(<String, Object?>{
        'version': 1, 'owner': owner, 'saved_at': now.toUtc().toIso8601String(),
        'items': items.take(100).map((c) => <String, Object>{
          'id': c.id, 'name': c.name,
        }).toList(growable: false),
      });

  static OrbitCircleSnapshot? decode(String? input, String owner, DateTime now) {
    if (input == null || input.length > 20000) return null;
    try {
      final decoded = jsonDecode(input);
      if (decoded is! Map || decoded['version'] != 1 || decoded['owner'] != owner) return null;
      final date = DateTime.parse(decoded['saved_at'] as String).toUtc();
      final age = now.toUtc().difference(date);
      if (age.isNegative || age > ttl) return null;
      final rows = decoded['items'];
      if (rows is! List || rows.length > 100) return null;
      return OrbitCircleSnapshot(rows.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return OrbitCircle(
          id: item['id'] as String,
          name: item['name'] as String,
          ownerId: '', role: 'offline', memberCount: 0, revision: 0,
        );
      }).toList(growable: false),date);
    } catch (_) {
      return null;
    }
  }
}

class OrbitCircleSnapshotStore {
  OrbitCircleSnapshotStore({OrbitIdentityClient? identity})
      : _identity = identity ?? OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

  Future<void> save(List<OrbitCircle> circles) async {
    final owner = await _identity.currentLocalSocialOwner();
    if (owner == null) return;
    await _identity.storeCirclesSnapshot(owner,
      OrbitCircleSnapshot.encode(owner,circles,DateTime.now()));
  }

  Future<OrbitCircleSnapshot?> read() async {
    final owner = await _identity.currentLocalSocialOwner();
    if (owner == null) return null;
    return OrbitCircleSnapshot.decode(
      await _identity.readCirclesSnapshot(), owner, DateTime.now());
  }

  Future<void> clear() => _identity.clearCirclesSnapshot();
}
