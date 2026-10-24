import 'dart:convert';

import '../../auth/data/orbit_identity_client.dart';
import '../../media/data/orbit_media_outbox.dart';

/// A publish request is captured only after the media has been sealed to the
/// M6 ciphertext-only outbox. Caption/targets are in OS secure storage; no
/// original camera/photo bytes are stored here or in SharedPreferences.
class OrbitStoredMomentIntent {
  const OrbitStoredMomentIntent({
    required this.owner,required this.transfer,required this.clientId,
    required this.audienceKind,required this.targetIds,required this.caption,
    required this.createdAt,this.placeLabel='',this.locationConsent=false,
    this.taggedUserIds=const [],this.attemptCount=0,this.retryAfter,
  });
  final String owner,transfer,clientId,audienceKind,caption;
  final List<String> targetIds;
  final String placeLabel;
  final bool locationConsent;
  final List<String> taggedUserIds;
  final int attemptCount;
  final DateTime? retryAfter;
  final DateTime createdAt;
  Map<String,dynamic> toJson()=> {
    'owner':owner,'transfer':transfer,'client_id':clientId,
    'audience_kind':audienceKind,'target_ids':targetIds,
    'caption':caption,'created_at':createdAt.toUtc().toIso8601String(),
    'place_label':placeLabel,'location_consent':locationConsent,
    'tagged_user_ids':taggedUserIds,
    'attempt_count':attemptCount,
    'retry_after':retryAfter?.toUtc().toIso8601String(),
  };
  factory OrbitStoredMomentIntent.fromJson(Map<String,dynamic> j) =>
    OrbitStoredMomentIntent(
      owner:j['owner'] as String,transfer:j['transfer'] as String,
      clientId:j['client_id'] as String,audienceKind:j['audience_kind'] as String,
      targetIds:List<String>.from(j['target_ids'] as List),
      caption:j['caption'] as String,
      placeLabel:j['place_label'] as String? ?? '',
      locationConsent:j['location_consent']==true,
      taggedUserIds:List<String>.from(j['tagged_user_ids'] as List? ?? const []),
      attemptCount:(j['attempt_count'] as num?)?.toInt()??0,
      retryAfter:j['retry_after'] is String
        ? DateTime.parse(j['retry_after'] as String).toUtc():null,
      createdAt:DateTime.parse(j['created_at'] as String).toUtc());
}

/// Each access checks the active account even when another account's vault
/// index still exists on the device. Queue replay is explicitly initiated by
/// an authenticated user; never publish from background isolates.
class OrbitMomentIntentVault {
  OrbitMomentIntentVault({OrbitMediaVault? vault,
    Future<String?> Function()? owner})
    : _vault=vault??OrbitPlatformMediaVault(),
      _owner=owner??OrbitIdentityClient.instance.currentLocalSocialOwner;
  final OrbitMediaVault _vault;
  final Future<String?> Function() _owner;

  String _index(String user) => 'orbit.m7.publish-index.$user';
  String _entry(String user,String transfer) => 'orbit.m7.publish.$user.$transfer';

  Future<void> _check(String user) async {
    final active=await _owner();
    if(active==null || active!=user)throw StateError(
      'A Moment draft cannot be used by a different account.');
  }

  Future<List<String>> _transfers(String user) async {
    final raw=await _vault.read(_index(user));
    if(raw==null)return [];
    final j=jsonDecode(raw);
    if(j is! List)throw const FormatException('Invalid private Moment index.');
    return List<String>.from(j);
  }

  Future<void> save(OrbitStoredMomentIntent intent) async {
    await _check(intent.owner);
    final transfers=await _transfers(intent.owner);
    if(transfers.contains(intent.transfer)) {
      final old=await read(intent.owner,intent.transfer);
      if(old!=null && old.clientId!=intent.clientId) {
        throw StateError('Encrypted draft is already assigned.');
      }
    }
    await _vault.write(_entry(intent.owner,intent.transfer),
      jsonEncode(intent.toJson()));
    if(!transfers.contains(intent.transfer)){
      transfers.add(intent.transfer);
      await _vault.write(_index(intent.owner),jsonEncode(transfers));
    }
  }

  Future<OrbitStoredMomentIntent?> read(String owner,String transfer) async {
    await _check(owner);
    final raw=await _vault.read(_entry(owner,transfer));
    if(raw==null)return null;
    final entry=OrbitStoredMomentIntent.fromJson(
      Map<String,dynamic>.from(jsonDecode(raw) as Map));
    if(entry.owner!=owner || entry.transfer!=transfer)throw const FormatException(
      'Private Moment draft ownership mismatch.');
    return entry;
  }

  Future<List<OrbitStoredMomentIntent>> pending(String owner) async {
    await _check(owner);
    final result=<OrbitStoredMomentIntent>[];
    for(final id in await _transfers(owner)){
      final entry=await read(owner,id);
      if(entry!=null)result.add(entry);
    }
    return result;
  }

  /// Record each attempted upload even if the network fails before any
  /// response. Limit automatic retries; the user may explicitly retry again.
  Future<OrbitStoredMomentIntent> markAttempt(String owner,String transfer) async {
    final old=await read(owner,transfer);
    if(old==null)throw StateError('Encrypted Moment intent disappeared.');
    final attempts=old.attemptCount+1;
    final seconds=(10*(1<<(attempts-1).clamp(0,6))).clamp(10,900);
    final next=OrbitStoredMomentIntent(
      owner:old.owner,transfer:old.transfer,clientId:old.clientId,
      audienceKind:old.audienceKind,targetIds:old.targetIds,
      caption:old.caption,createdAt:old.createdAt,
      placeLabel:old.placeLabel,locationConsent:old.locationConsent,
      taggedUserIds:old.taggedUserIds,
      attemptCount:attempts,retryAfter:DateTime.now().toUtc()
        .add(Duration(seconds:seconds)),
    );
    await _vault.write(_entry(owner,transfer),jsonEncode(next.toJson()));
    return next;
  }

  Future<void> remove(String owner,String transfer) async {
    await _check(owner);
    await _vault.delete(_entry(owner,transfer));
    final index=await _transfers(owner);
    index.remove(transfer);
    await _vault.write(_index(owner),jsonEncode(index));
  }
}
