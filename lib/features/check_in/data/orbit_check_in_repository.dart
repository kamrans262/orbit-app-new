import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../auth/data/orbit_identity_client.dart';

class OrbitCheckInScope {
  const OrbitCheckInScope(this.type,[this.id]);
  final String type;
  final String? id;
  Map<String,Object?> toJson()=>{'type':type,if(id!=null)'id':id};
  factory OrbitCheckInScope.fromJson(Map<String,dynamic> v)=>
    OrbitCheckInScope(v['type'] as String,v['id'] as String?);
  static const onlyMe=OrbitCheckInScope('only_me');
  static const friends=OrbitCheckInScope('friends');
}
class OrbitCheckInRecord {
  const OrbitCheckInRecord({required this.id,required this.creatorId,
    required this.creatorName,required this.type,required this.status,
    required this.revision,required this.createdAt,this.text,this.expiresAt,
    this.audience=const []});
  final String id,creatorId,creatorName,type,status;
  final int revision;
  final String? text;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<OrbitCheckInScope> audience;
  factory OrbitCheckInRecord.fromJson(Map<String,dynamic> v){
    final owner=Map<String,dynamic>.from(v['creator'] as Map);
    final raw=v['audience'];
    return OrbitCheckInRecord(
      id:v['id'] as String,creatorId:owner['id'] as String,
      creatorName:owner['name'] as String? ?? 'Orbit member',
      type:v['type'] as String,status:v['status'] as String,
      revision:(v['audience_revision'] as num).toInt(),
      text:v['text'] as String?,
      createdAt:DateTime.parse(v['created_at'] as String),
      expiresAt:DateTime.tryParse(v['expires_at'] as String? ?? ''),
      audience:raw is List ? raw.map((x)=>OrbitCheckInScope.fromJson(
        Map<String,dynamic>.from(x as Map))).toList() : const [],
    );
  }
  String get label=>type=='custom'?(text??'Custom Check-In'):
    const <String,String>{'home':'Home','work':'Work','driving':'Driving',
      'gym':'Gym','travel':'Travel','coffee':'Coffee','eating':'Eating',
      'chill':'Chill','sleep':'Sleep'}[type]??type;
}
class OrbitCheckInPage {
  const OrbitCheckInPage(this.items,this.nextCursor);
  final List<OrbitCheckInRecord> items;
  final String? nextCursor;
}
class OrbitPendingCheckIn {
  const OrbitPendingCheckIn({required this.clientId,required this.type,
    required this.audience,this.text,this.expiresAt});
  final String clientId,type;
  final String? text,expiresAt;
  final List<OrbitCheckInScope> audience;
  Map<String,Object?> toJson()=>{'client_id':clientId,'type':type,
    if(text!=null)'text':text,'audience':audience.map((a)=>a.toJson()).toList(),
    if(expiresAt!=null)'expires_at':expiresAt};
  factory OrbitPendingCheckIn.fromJson(Map<String,dynamic> v)=>
    OrbitPendingCheckIn(clientId:v['client_id'] as String,
      type:v['type'] as String,text:v['text'] as String?,
      expiresAt:v['expires_at'] as String?,
      audience:(v['audience'] as List).map((x)=>OrbitCheckInScope.fromJson(
        Map<String,dynamic>.from(x as Map))).toList());
}
enum OrbitCheckInSendState { accepted, queued }

/// No cached recipient feed: all reads reauthorize on the server.
/// OS-backed storage contains only account-bound pending send intents.
class OrbitCheckInRepository {
  OrbitCheckInRepository({OrbitIdentityClient? identity,
    FlutterSecureStorage? storage}):_identity=identity??OrbitIdentityClient.instance,
      _storage=storage??const FlutterSecureStorage();
  final OrbitIdentityClient _identity;
  final FlutterSecureStorage _storage;
  static const pendingPrefix='orbit.checkin.pending.v1.';
  static const audiencePrefix='orbit.checkin.audience.v1.';
  Future<void>? _replay;
  Future<String> _owner() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null||owner.isEmpty)throw OrbitIdentityException('Sign in to Check-In.',401);
    return owner;
  }
  Future<Map<String,dynamic>> _request(String method,String path,
      {Map<String,Object?>? body}) async {
    final response=await _identity.socialRequest(method,path,body:body);
    if(response['data'] is! Map)throw const FormatException('Invalid Check-In response.');
    return Map<String,dynamic>.from(response['data'] as Map);
  }
  String _id(String value)=>Uri.encodeComponent(value);
  Future<bool> available() async =>
    (await _request('GET','/check-ins/capabilities'))['available']==true;
  Future<Map<String,dynamic>> privacy()=>_identity.privacyPreferences();
  Future<OrbitCheckInPage> page(String kind,{String? cursor,int limit=20}) async {
    if(kind!='mine'&&kind!='feed')throw ArgumentError('Invalid Check-In list');
    final query=Uri(queryParameters:{'limit':'$limit',if(cursor!=null)'cursor':cursor}).query;
    final data=await _request('GET','/check-ins/'+kind+'?'+query);
    final raw=data['items'];
    if(raw is! List)throw const FormatException('Invalid Check-In page.');
    return OrbitCheckInPage(raw.map((x)=>OrbitCheckInRecord.fromJson(
      Map<String,dynamic>.from(x as Map))).toList(),data['next_cursor'] as String?);
  }
  Future<OrbitCheckInRecord> detail(String id) async =>
    OrbitCheckInRecord.fromJson(await _request('GET','/check-ins/'+_id(id)));
  Future<OrbitCheckInRecord> changeAudience(String id,int revision,
      List<OrbitCheckInScope> scopes) async =>
    OrbitCheckInRecord.fromJson(await _request('PUT',
      '/check-ins/'+_id(id)+'/audience',body:{
        'expected_revision':revision,'audience':scopes.map((a)=>a.toJson()).toList()}));
  Future<OrbitCheckInRecord> changeExpiry(String id,DateTime? expires) async =>
    OrbitCheckInRecord.fromJson(await _request('PATCH','/check-ins/'+_id(id),
      body:{'expires_at':expires?.toUtc().toIso8601String()}));
  Future<void> withdraw(String id) async {
    await _identity.socialRequest('DELETE','/check-ins/'+_id(id));
  }
  Future<bool> circleConsent(String id) async =>
    (await _request('GET','/me/check-ins/circles/'+_id(id)+'/consent'))['enabled']==true;
  Future<bool> setCircleConsent(String id,bool enabled) async =>
    (await _request('PUT','/me/check-ins/circles/'+_id(id)+'/consent',
      body:{'enabled':enabled,if(enabled)'confirm':true}))['enabled']==true;
  Future<List<OrbitPendingCheckIn>> _read(String owner) async {
    try {
      final value=await _storage.read(key:'$pendingPrefix$owner');
      if(value==null)return [];
      final raw=jsonDecode(value);
      if(raw is! List)return [];
      return raw.map((x)=>OrbitPendingCheckIn.fromJson(
        Map<String,dynamic>.from(x as Map))).take(25).toList();
    }catch(_){return [];}
  }
  Future<void> _write(String owner,List<OrbitPendingCheckIn> rows) async {
    if(await _identity.currentLocalSocialOwner()!=owner)return;
    await _storage.write(key:'$pendingPrefix$owner',
      value:jsonEncode(rows.map((e)=>e.toJson()).toList()));
  }
  Future<List<OrbitPendingCheckIn>> pending() async =>
    List.unmodifiable(await _read(await _owner()));
  Future<void> rememberAudience(List<OrbitCheckInScope> scopes) async {
    final owner=await _owner();
    if(await _identity.currentLocalSocialOwner()!=owner)return;
    await _storage.write(key:'$audiencePrefix$owner',
      value:jsonEncode(scopes.map((s)=>s.toJson()).toList()));
  }
  Future<List<OrbitCheckInScope>> lastAudience() async {
    final owner=await _owner();
    try{
      final raw=await _storage.read(key:'$audiencePrefix$owner');
      if(raw==null)return const [];
      final values=jsonDecode(raw);
      if(values is! List || values.length>25)return const [];
      return values.map((x)=>OrbitCheckInScope.fromJson(
        Map<String,dynamic>.from(x as Map))).toList();
    }catch(_){return const [];}
  }
  Future<void> purge(String owner) async {
    await _storage.delete(key:'$pendingPrefix$owner');
    await _storage.delete(key:'$audiencePrefix$owner');
  }
  bool _retryable(Object e)=>e is OrbitIdentityException &&
    (e.statusCode==null||e.statusCode==408||e.statusCode==502||e.statusCode==504);
  Future<OrbitCheckInSendState> send({required String type,
    required List<OrbitCheckInScope> audience,String? text,DateTime? expires}) async {
    final owner=await _owner();
    if(!const {'home','work','driving','gym','travel','coffee','eating',
      'chill','sleep','custom'}.contains(type))throw ArgumentError('Invalid activity');
    if(audience.isEmpty||audience.length>25)throw ArgumentError('Choose an audience.');
    if(type=='custom'&&(text==null||text.trim().isEmpty||text.trim().runes.length>160)){
      throw ArgumentError('Custom Check-In must be 1–160 characters.');
    }
    final rows=await _read(owner);
    if(rows.length>=25)throw OrbitIdentityException('Retry pending Check-Ins first.',429);
    final intent=OrbitPendingCheckIn(clientId:const Uuid().v4(),type:type,
      audience:audience,text:type=='custom'?text!.trim():null,
      expiresAt:expires?.toUtc().toIso8601String());
    rows.add(intent);
    await _write(owner,rows);
    try{
      await _request('POST','/check-ins',body:intent.toJson());
      final current=await _read(owner);
      current.removeWhere((p)=>p.clientId==intent.clientId);
      await _write(owner,current);
      await rememberAudience(audience);
      return OrbitCheckInSendState.accepted;
    }catch(e){
      if(_retryable(e))return OrbitCheckInSendState.queued;
      final current=await _read(owner);
      current.removeWhere((p)=>p.clientId==intent.clientId);
      await _write(owner,current);
      rethrow;
    }
  }
  Future<void> retryPending()=>flushPending();
  Future<void> flushPending() async {
    if(_replay!=null)return _replay!;
    final future=_flush();
    _replay=future;
    try{await future;}finally{_replay=null;}
  }
  Future<void> _flush() async {
    final owner=await _owner();
    final rows=await _read(owner);
    for(final intent in rows.toList()){
      if(await _identity.currentLocalSocialOwner()!=owner)return;
      try{
        await _request('POST','/check-ins',body:intent.toJson());
        rows.removeWhere((p)=>p.clientId==intent.clientId);
        await rememberAudience(intent.audience);
      }catch(e){
        if(_retryable(e))break;
        rows.removeWhere((p)=>p.clientId==intent.clientId);
      }
      await _write(owner,rows);
    }
  }
}
