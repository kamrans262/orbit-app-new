import 'dart:convert';
import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_outbox.dart';

/// Strictly viewer-local Story seen state. It never becomes a public counter,
/// author analytics, or a notification claiming delivery.
class OrbitMomentSeenVault {
  OrbitMomentSeenVault({OrbitMediaVault? vault,
    Future<String?> Function()? owner})
    : _vault=vault??OrbitPlatformMediaVault(),
      _owner=owner??OrbitIdentityClient.instance.currentLocalSocialOwner;
  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;
  String _key(String owner)=>'orbit.m7.story-seen.'+owner;
  Future<String> _requireOwner() async {
    final owner=await _owner();
    if(owner==null)throw StateError('Sign in to view private Moments.');
    return owner;
  }
  Future<Map<String,DateTime>> _all(String owner) async {
    final raw=await _vault.read(_key(owner));
    if(raw==null)return {};
    final parsed=jsonDecode(raw);
    if(parsed is! Map)throw const FormatException('Invalid private viewer receipts.');
    final now=DateTime.now().toUtc();
    final result=<String,DateTime>{};
    for(final item in parsed.entries){
      if(item.key is! String || item.value is! String)continue;
      final when=DateTime.tryParse(item.value as String)?.toUtc();
      if(when!=null && when.isBefore(now.add(const Duration(minutes:10)))
          && now.difference(when)<const Duration(days:7)){
        result[item.key as String]=when;
      }
    }
    return result;
  }
  Future<Set<String>> seenIds(Iterable<String> ids) async {
    final owner=await _requireOwner();
    final saved=await _all(owner);
    return ids.where(saved.containsKey).toSet();
  }
  Future<void> markSeen(String momentId) async {
    final owner=await _requireOwner();
    final all=await _all(owner);
    all[momentId]=DateTime.now().toUtc();
    final entries=all.entries.toList()
      ..sort((a,b)=>b.value.compareTo(a.value));
    final limited=entries.take(500);
    await _vault.write(_key(owner),jsonEncode({
      for(final e in limited)e.key:e.value.toIso8601String(),
    }));
  }
}
