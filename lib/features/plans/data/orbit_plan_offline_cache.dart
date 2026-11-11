import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A bounded, encrypted, read-only record of the last server-authorized
/// Plans. Offline records are never authorization grants and cannot be used
/// to mutate Plans. The UI must label them as last verified, not live.
class OrbitPlanOfflineCache {
  OrbitPlanOfflineCache({FlutterSecureStorage? storage})
    :_storage=storage??const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const storageKey='orbit.plans.offline.verified.v1';
  static const maxAge=Duration(hours:24);
  static const maxDetails=20;
  static const schemaVersion=1;

  Future<Map<String,dynamic>?> _documentFor(String owner) async {
    final raw=await _storage.read(key:storageKey);
    if(raw==null)return null;
    try{
      final parsed=jsonDecode(raw);
      if(parsed is! Map)throw const FormatException('Plan cache');
      final doc=Map<String,dynamic>.from(parsed);
      final time=DateTime.tryParse(doc['verified_at'] as String? ?? '');
      if(doc['version']!=schemaVersion || doc['owner']!=owner ||
         time==null || time.isAfter(DateTime.now().add(const Duration(minutes:5))) ||
         DateTime.now().difference(time)>maxAge){
        await clear();
        return null;
      }
      return doc;
    }catch(_){await clear();return null;}
  }

  Future<void> rememberList(String owner,String tab,List<Map<String,dynamic>> items) async {
    if(!const {'upcoming','past'}.contains(tab))return;
    final existing=await _documentFor(owner);
    final lists=existing?['lists'] is Map
        ?Map<String,dynamic>.from(existing!['lists'] as Map)
        :<String,dynamic>{};
    final details=existing?['details'] is Map
        ?Map<String,dynamic>.from(existing!['details'] as Map)
        :<String,dynamic>{};
    lists[tab]=items.take(30).toList(growable:false);
    await _write(owner,lists,details);
  }

  Future<void> rememberDetail(String owner,String id,Map<String,dynamic> plan) async {
    if(plan['id']!=id)return;
    final existing=await _documentFor(owner);
    final lists=existing?['lists'] is Map
        ?Map<String,dynamic>.from(existing!['lists'] as Map)
        :<String,dynamic>{};
    final details=existing?['details'] is Map
        ?Map<String,dynamic>.from(existing!['details'] as Map)
        :<String,dynamic>{};
    details.remove(id);
    details[id]=plan;
    while(details.length>maxDetails){details.remove(details.keys.first);}
    await _write(owner,lists,details);
  }

  Future<void> _write(String owner,Map<String,dynamic> lists,
      Map<String,dynamic> details) async {
    await _storage.write(key:storageKey,value:jsonEncode({
      'version':schemaVersion,'owner':owner,
      'verified_at':DateTime.now().toUtc().toIso8601String(),
      'lists':lists,'details':details,
    }));
  }

  Future<List<Map<String,dynamic>>?> lastList(String owner,String tab) async {
    final doc=await _documentFor(owner);
    final lists=doc?['lists'];
    if(lists is! Map || lists[tab] is! List)return null;
    try{
      return (lists[tab] as List).map((e)=>
        Map<String,dynamic>.from(e as Map)).toList(growable:false);
    }catch(_){await clear();return null;}
  }

  Future<Map<String,dynamic>?> lastDetail(String owner,String id) async {
    final doc=await _documentFor(owner);
    final details=doc?['details'];
    if(details is! Map || details[id] is! Map)return null;
    try{return Map<String,dynamic>.from(details[id] as Map);}
    catch(_){await clear();return null;}
  }

  Future<void> clear()=>_storage.delete(key:storageKey);
}
