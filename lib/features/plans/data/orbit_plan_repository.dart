import '../../auth/data/orbit_identity_client.dart';
import '../domain/orbit_plan_models.dart';

/// All M15 calls use the existing bearer token, trusted-device checks,
/// centralized timeouts and refresh handling. No private disk snapshots.
class OrbitPlanRepository {
  OrbitPlanRepository({OrbitIdentityClient? identity})
    : _identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

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
    final result=await _call('GET',Uri(path:'/plans',queryParameters:params).toString());
    final data=result['data'],meta=result['meta'];
    if(data is! List)throw const FormatException('Invalid Plan list.');
    final next=meta is Map?meta['next_cursor']:null;
    if(next!=null && next is! String)throw const FormatException('Invalid Plan cursor.');
    return OrbitPlanPage(data.map((e)=>OrbitPlan.fromJson(
      Map<String,dynamic>.from(e as Map))).toList(growable:false),next as String?);
  }

  Future<OrbitPlan> detail(String id) async=>OrbitPlan.fromJson(
    await _data('GET','/plans/'+Uri.encodeComponent(id)));

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
      if(endsAt!=null)'ends_at':endsAt.toUtc().toIso8601String(),
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
