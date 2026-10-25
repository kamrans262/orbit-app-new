import 'dart:convert';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_outbox.dart';

/// The previous audience is only a SUGGESTION, never an authorization grant.
/// All target IDs are rechecked against currently eligible friends/Circles
/// before the user can select the suggestion and again by Laravel on publish.
class OrbitMomentAudiencePreference {
  const OrbitMomentAudiencePreference(this.kind, this.targetIds);
  final String kind;
  final List<String> targetIds;
}

class OrbitMomentAudienceMemory {
  OrbitMomentAudienceMemory({
    OrbitMediaVault? vault,
    Future<String?> Function()? owner,
  }) : _vault = vault ?? OrbitPlatformMediaVault(),
       _owner = owner ?? OrbitIdentityClient.instance.currentLocalSocialOwner;

  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;

  Future<String> _key() async {
    final account = await _owner();
    if (account == null || account.isEmpty) {
      throw StateError('An authenticated Orbit account is required.');
    }
    return 'orbit.m7.previous-audience.$account';
  }

  Future<OrbitMomentAudiencePreference?> read() async {
    final key = await _key();
    final raw = await _vault.read(key);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    final kind = data['kind'];
    final targets = data['targets'];
    if (kind is! String || targets is! List ||
        !const {'only_me', 'accepted_friends', 'selected_friends',
                'selected_circles'}.contains(kind)) return null;
    final ids = targets.whereType<String>().toSet().toList();
    if (ids.length > 100) return null;
    return OrbitMomentAudiencePreference(kind, ids);
  }

  Future<void> save(String kind, Iterable<String> targets) async {
    if (!const {'only_me', 'accepted_friends', 'selected_friends',
                 'selected_circles'}.contains(kind)) {
      throw const FormatException('Invalid Moment audience preference.');
    }
    final ids = targets.toSet().toList();
    if (ids.length > 100) {
      throw const FormatException('Too many audience recipients.');
    }
    await _vault.write(await _key(), jsonEncode({
      'kind': kind,
      'targets': ids,
    }));
  }

  Future<void> clear() async => _vault.delete(await _key());

  Future<void> purge(String oldOwner) async {
    if(oldOwner.isEmpty)return;
    await _vault.delete('orbit.m7.previous-audience.$oldOwner');
  }
}
