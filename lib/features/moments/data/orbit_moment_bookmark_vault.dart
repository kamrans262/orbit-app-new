import 'dart:convert';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_outbox.dart';

/// Account-scoped, metadata-only bookmarks. NEVER a saved media file, grant,
/// authorization lease or offline playback entitlement.
class OrbitMomentBookmarkVault {
  OrbitMomentBookmarkVault({OrbitMediaVault? vault,
    Future<String?> Function()? owner})
    : _vault=vault??OrbitPlatformMediaVault(),
      _owner=owner??OrbitIdentityClient.instance.currentLocalSocialOwner;
  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;
  String _key(String user)=>'orbit.m7.bookmarks.$user';

  Future<String> _account() async {
    final user=await _owner();
    if(user==null||user.isEmpty)throw StateError('Sign in to view bookmarks.');
    return user;
  }

  Future<Map<String,DateTime>> _entries(String account) async {
    final raw=await _vault.read(_key(account));
    if(raw==null)return {};
    final parsed=jsonDecode(raw);
    if(parsed is! Map)throw const FormatException('Invalid bookmark vault.');
    final valid=<String,DateTime>{};
    final now=DateTime.now().toUtc();
    for(final entry in parsed.entries){
      if(entry.key is! String||entry.value is! String)continue;
      final until=DateTime.tryParse(entry.value as String)?.toUtc();
      if(until!=null && now.isBefore(until))valid[entry.key as String]=until;
    }
    return valid;
  }

  Future<Set<String>> authorizedIds(Map<String,DateTime> authorized) async {
    final user=await _account();
    final entries=await _entries(user);
    final now=DateTime.now().toUtc();
    return authorized.entries
      .where((e)=>entries.containsKey(e.key) &&
        now.isBefore(e.value.toUtc().add(const Duration(days:7))) &&
        now.isBefore(entries[e.key]!))
      .map((e)=>e.key).toSet();
  }

  Future<void> setSaved(String momentId,String context,DateTime publishedAt,
      {required bool saved}) async {
    final user=await _account();
    final entries=await _entries(user);
    final key='$momentId|$context';
    if(saved){
      final expiry=publishedAt.toUtc().add(const Duration(days:7));
      if(!DateTime.now().toUtc().isBefore(expiry)){
        throw StateError('Expired Moments cannot be saved.');
      }
      entries[key]=expiry;
    }else{
      entries.remove(key);
    }
    final limited=entries.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    await _vault.write(_key(user),jsonEncode({
      for(final entry in limited.take(250))
        entry.key:entry.value.toIso8601String(),
    }));
  }
}
