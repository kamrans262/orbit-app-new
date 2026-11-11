import '../../auth/data/orbit_identity_client.dart';
import '../domain/orbit_plan_models.dart';
import 'orbit_plan_offline_cache.dart';

/// All M15 calls use existing bearer tokens, trusted-device checks,
/// centralized timeouts and refresh handling. The optional offline cache
/// uses encrypted secure storage for last-authorized read-only snapshots.
class OrbitPlanRepository {
  OrbitPlanRepository({OrbitIdentityClient? identity})
    : _identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;
  final OrbitPlanOfflineCache _cache=OrbitPlanOfflineCache();

  static bool temporaryOffline(Object error) =>
    error is OrbitIdentityException &&
    (error.statusCode==null || error.statusCode==502 || error.statusCode==504);

  Future<void> clearCachedPlans()=>_cache.clear();

  Future<OrbitPlanPage?> lastVerifiedList(String tab) async {
    final owner=await _owner();
    final records=await _cache.lastList(owner,tab);
    if(records==null)return null;
    try{
      return OrbitPlanPage(records.map(OrbitPlan.fromJson)
          .toList(growable:false),null);
    }catch(_){await _cache.clear();return null;}
  }

  Future<OrbitPlan?> lastVerifiedDetail(String id) async {
    final owner=await _owner();
    final value=await _cache.lastDetail(owner,id);
    if(value==null)return null;
    try{return OrbitPlan.fromJson(value);}
    catch(_){await _cache.clear();return null;}
  }

  Future<String> _owner() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null||owner.isEmpty) {
      throw OrbitIdentityException('Sign in to access Plans.',401);
    }
    return owner;
  }

  Future<Map<String,dynamic>> _call(String method,String path,{
      Map<String,Object?>? body}) async {
    final owner=await _owner();
    final response=await _identity.socialRequest(method,path,body:body);
    if(await _identity.currentLocalSocialOwner()!=owner){
      throw OrbitIdentityException('Account changed. Reload Plans.',401);
    }
    return response;
  }

  Future<Map<String,dynamic>> _data(String method,String path,{
      Map<String,Object?>? body}) async {
    final raw=(await _call(method,path,body:body))['data'];
    if(raw is! Map)throw const FormatException('Invalid Plan payload.');
    return Map<String,dynamic>.from(raw);
  }

  Future<OrbitPlanPage> list({String tab='upcoming',int limit=20,String? cursor}) async {
    if(!const {'upcoming','past'}.contains(tab))throw ArgumentError.value(tab);
    final params=<String,String>{'tab':tab,'limit':'$limit'};
    if(cursor!=null && cursor.isNotEmpty)params['cursor']=cursor;
    final owner=await _owner();
    final result=await _call('GET',Uri(path:'/plans',queryParameters:params).toString());
    final data=result['data'],meta=result['meta'];
    if(data is! List)throw const FormatException('Invalid Plan list.');
    final next=meta is Map?meta['next_cursor']:null;
    if(next!=null && next is! String)throw const FormatException('Invalid Plan cursor.');
    final rows=data.map((e)=>Map<String,dynamic>.from(e as Map))
      .toList(growable:false);
    final items=rows.map(OrbitPlan.fromJson).toList(growable:false);
    if(cursor==null && await _identity.currentLocalSocialOwner()==owner){
      try{await _cache.rememberList(owner,tab,rows);}catch(_){}
    }
    return OrbitPlanPage(items,next as String?);
  }

  Future<OrbitPlan> detail(String id) async {
    final owner=await _owner();
    final response=await _data('GET','/plans/'+Uri.encodeComponent(id));
    final plan=OrbitPlan.fromJson(response);
    if(await _identity.currentLocalSocialOwner()==owner){
      try{await _cache.rememberDetail(owner,id,response);}catch(_){}
    }
    return plan;
  }

  Future<OrbitPlan> create({required String clientId,required String title,
    required DateTime startsAt,DateTime? endsAt,String description='',
    String? placeLabel,List<String> inviteeIds=const [],
    List<String> circleIds=const []}) async=>OrbitPlan.fromJson(
    await _data('POST','/plans',body:{
      'client_id':clientId,'title':title.trim(),
      'starts_at':startsAt.toUtc().toIso8601String(),
      if(endsAt!=null)'ends_at':endsAt.toUtc().toIso8601String(),
      'description':description.trim(),
      if(placeLabel!=null && placeLabel.trim().isNotEmpty)
        'place_label':placeLabel.trim(),
      'invitee_ids':inviteeIds,'circle_ids':circleIds,
    }));

  Future<OrbitPlan> update(String id,{required int revision,String? title,
    String? description,DateTime? startsAt,DateTime? endsAt,
    String? placeLabel,List<String>? inviteeIds,List<String>? circleIds}) async=>
    OrbitPlan.fromJson(await _data('PATCH','/plans/'+Uri.encodeComponent(id),body:{
      'revision':revision,
      if(title!=null)'title':title.trim(),
      if(description!=null)'description':description.trim(),
      if(startsAt!=null)'starts_at':startsAt.toUtc().toIso8601String(),
      'ends_at':endsAt?.toUtc().toIso8601String(),
      if(placeLabel!=null)'place_label':placeLabel.trim(),
      if(inviteeIds!=null)'invitee_ids':inviteeIds,
      if(circleIds!=null)'circle_ids':circleIds,
    }));

  Future<OrbitPlan> cancel(String id,int revision) async=>
    OrbitPlan.fromJson(await _data('POST',
      '/plans/'+Uri.encodeComponent(id)+'/cancel',body:{'revision':revision}));

  Future<OrbitPlan> rsvp(String id,String state) async {
    if(!const {'joined','declined'}.contains(state))throw ArgumentError.value(state);
    return OrbitPlan.fromJson(await _data('POST',
      '/plans/'+Uri.encodeComponent(id)+'/rsvp',body:{'state':state}));
  }

  Future<OrbitPlan> leave(String id) async=>OrbitPlan.fromJson(
    await _data('POST','/plans/'+Uri.encodeComponent(id)+'/leave'));

  Future<List<OrbitPlanPerson>> participants(String id) async {
    final data=(await _call('GET','/plans/'+Uri.encodeComponent(id)+'/participants'))['data'];
    if(data is! List)throw const FormatException('Invalid Plan participants.');
    return data.map((e)=>OrbitPlanPerson.fromJson(
      Map<String,dynamic>.from(e as Map))).toList(growable:false);
  }

  Future<OrbitPlanReminderPreferences> reminderPreferences() async=>
    OrbitPlanReminderPreferences.fromJson(
      await _data('GET','/me/plans/reminder-preferences'));

  Future<OrbitPlanReminderPreferences> saveReminderPreferences({
    required bool enabled,required List<int> offsets}) async=>
    OrbitPlanReminderPreferences.fromJson(
      await _data('PUT','/me/plans/reminder-preferences',
        body:{'enabled':enabled,'offsets_minutes':offsets}));
}
