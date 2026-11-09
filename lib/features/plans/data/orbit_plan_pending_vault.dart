import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted OS-keystore-backed single pending create intent. No automatic
/// background send: only the trusted foreground account can explicitly retry.
class OrbitPlanPendingDraft {
  const OrbitPlanPendingDraft({
    required this.owner,required this.clientId,required this.title,
    required this.description,required this.placeLabel,required this.startsAt,
    required this.endsAt,required this.inviteeIds,required this.circleIds,
    required this.savedAt,
  });
  final String owner,clientId,title,description,placeLabel;
  final DateTime startsAt,savedAt;
  final DateTime? endsAt;
  final List<String> inviteeIds,circleIds;
  Map<String,dynamic> toJson()=>{
    'owner':owner,'client_id':clientId,'title':title,
    'description':description,'place_label':placeLabel,
    'starts_at':startsAt.toUtc().toIso8601String(),
    'ends_at':endsAt?.toUtc().toIso8601String(),
    'invitee_ids':inviteeIds,'circle_ids':circleIds,
    'saved_at':savedAt.toUtc().toIso8601String(),
  };
  static OrbitPlanPendingDraft? fromJson(Map<String,dynamic> data) {
    try {
      final start=DateTime.parse(data['starts_at'] as String);
      final saved=DateTime.parse(data['saved_at'] as String);
      final end=data['ends_at'] is String
        ?DateTime.parse(data['ends_at'] as String):null;
      return OrbitPlanPendingDraft(
        owner:data['owner'] as String,clientId:data['client_id'] as String,
        title:data['title'] as String,description:data['description'] as String,
        placeLabel:data['place_label'] as String,startsAt:start.toLocal(),
        endsAt:end?.toLocal(),
        inviteeIds:(data['invitee_ids'] as List).cast<String>(),
        circleIds:(data['circle_ids'] as List).cast<String>(),
        savedAt:saved,
      );
    }catch(_){return null;}
  }
}

class OrbitPlanPendingVault {
  OrbitPlanPendingVault({FlutterSecureStorage? storage})
    :_storage=storage??const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const key='orbit.plans.pending.create.v1';

  Future<void> store(OrbitPlanPendingDraft draft) async {
    await _storage.write(key:key,value:jsonEncode(draft.toJson()));
  }

  Future<OrbitPlanPendingDraft?> readFor(String currentOwner) async {
    final raw=await _storage.read(key:key);
    if(raw==null)return null;
    OrbitPlanPendingDraft? data;
    try{
      final json=jsonDecode(raw);
      if(json is Map)data=OrbitPlanPendingDraft.fromJson(
        Map<String,dynamic>.from(json));
    }catch(_){}
    if(data==null||data.owner!=currentOwner||
        data.savedAt.isAfter(DateTime.now().add(const Duration(minutes:5)))||
        DateTime.now().difference(data.savedAt)>const Duration(days:7)){
      await clear();
      return null;
    }
    return data;
  }

  Future<void> clearIfMatches(String owner,String clientId) async {
    final raw=await _storage.read(key:key);
    if(raw==null)return;
    try{
      final data=OrbitPlanPendingDraft.fromJson(
        Map<String,dynamic>.from(jsonDecode(raw) as Map));
      if(data?.owner==owner && data?.clientId==clientId)await clear();
    }catch(_){await clear();}
  }

  Future<void> clear()=>_storage.delete(key:key);
}
