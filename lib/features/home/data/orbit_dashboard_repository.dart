import '../../auth/data/orbit_identity_client.dart';

enum DashboardState { ready, empty, disabled, unavailable, permissionDenied }
DashboardState dashboardState(Object? s)=>switch(s) {
  'ready'=>DashboardState.ready,
  'empty'=>DashboardState.empty,
  'disabled'=>DashboardState.disabled,
  'permission_denied'=>DashboardState.permissionDenied,
  _=>DashboardState.unavailable,
};
class DashboardSection<T> {
  const DashboardSection(this.state,this.items);
  final DashboardState state;
  final List<T> items;
  factory DashboardSection.parse(Object? raw,T Function(Map<String,dynamic>) decoder) {
    if(raw is! Map)throw const FormatException('Invalid M8 section.');
    final v=Map<String,dynamic>.from(raw),state=dashboardState(v['state']);
    if(state!=DashboardState.ready && state!=DashboardState.empty) {
      return DashboardSection<T>(state,<T>[]);
    }
    if(v['items'] is! List)throw const FormatException('Missing M8 items.');
    return DashboardSection<T>(state,(v['items'] as List)
      .map((x)=>decoder(Map<String,dynamic>.from(x as Map))).toList(growable:false));
  }
}
class DashboardCircle {
  const DashboardCircle(this.id,this.name,this.role,this.memberCount,this.iconKey,this.colorValue);
  final String id,name,role;
  final int memberCount;
  final String? iconKey,colorValue;
  factory DashboardCircle.parse(Map<String,dynamic> m) {
    if(m['id'] is! String||m['name'] is! String)throw const FormatException('Invalid Circle.');
    return DashboardCircle(m['id'] as String,m['name'] as String,
      m['role'] as String? ?? 'member',(m['member_count'] as num?)?.toInt()??0,
      m['icon_key'] as String?,m['color_value'] as String?);
  }
}
class DashboardPerson {
  const DashboardPerson(this.id,this.name);
  final String id,name;
  factory DashboardPerson.parse(Map<String,dynamic> m) {
    if(m['id'] is! String||m['display_name'] is! String||m['relationship']!='friend') {
      throw const FormatException('Invalid friend.');
    }
    return DashboardPerson(m['id'] as String,m['display_name'] as String);
  }
}
class DashboardMomentReference {
  const DashboardMomentReference(this.id,this.revision);
  final String id;
  final int revision;
  factory DashboardMomentReference.parse(Map<String,dynamic> m) {
    if(m['id'] is! String||m['audience_revision'] is! num) {
      throw const FormatException('Invalid Moment reference.');
    }
    return DashboardMomentReference(m['id'] as String,(m['audience_revision'] as num).toInt());
  }
}
class OrbitDashboardSnapshot {
  const OrbitDashboardSnapshot({required this.name,required this.revision,
    required this.generatedAt,required this.circles,required this.people,
    required this.moments,required this.capabilities,required this.plansState});
  final String name,revision;
  final DateTime generatedAt;
  final DashboardSection<DashboardCircle> circles;
  final DashboardSection<DashboardPerson> people;
  final DashboardSection<DashboardMomentReference> moments;
  final Map<String,bool> capabilities;
  final DashboardState plansState;
  bool can(String key)=>capabilities[key]==true;
  factory OrbitDashboardSnapshot.parse(Map<String,dynamic> j) {
    if(j['schema_version']!=1||j['sections'] is! Map||
       j['capabilities'] is! Map||j['greeting'] is! Map) {
      throw const FormatException('Unsupported M8 Dashboard schema.');
    }
    final sections=Map<String,dynamic>.from(j['sections'] as Map);
    final greeting=Map<String,dynamic>.from(j['greeting'] as Map);
    final generated=DateTime.tryParse(j['generated_at'] as String? ?? '');
    if(generated==null||greeting['display_name'] is! String) {
      throw const FormatException('Invalid viewer greeting.');
    }
    final c=Map<String,dynamic>.from(j['capabilities'] as Map);
    return OrbitDashboardSnapshot(
      name:greeting['display_name'] as String,
      revision:j['viewer_policy_revision'] as String? ?? '',
      generatedAt:generated,
      circles:DashboardSection.parse(sections['circles'],DashboardCircle.parse),
      people:DashboardSection.parse(sections['people'],DashboardPerson.parse),
      moments:DashboardSection.parse(sections['moments'],DashboardMomentReference.parse),
      plansState:dashboardState((sections['plans'] as Map?)?['state']),
      capabilities:c.map((k,v)=>MapEntry(k,v==true)));
  }
}
/// Reuses M2 session refresh, device trust and timeout.
class OrbitDashboardRepository {
  OrbitDashboardRepository({OrbitIdentityClient? identity})
    : _identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;
  Future<OrbitDashboardSnapshot> summary() async {
    final response=await _identity.socialRequest('GET','/dashboard/summary');
    if(response['data'] is! Map)throw const FormatException('Invalid M8 envelope.');
    return OrbitDashboardSnapshot.parse(Map<String,dynamic>.from(response['data'] as Map));
  }
  Future<void> orderCircles(List<String> ids) async {
    await _identity.socialRequest('PUT','/me/dashboard/preferences',body:{'circle_order':ids});
  }
  Future<void> dismiss(String key) async {
    await _identity.socialRequest('POST','/me/dashboard/cards/'+Uri.encodeComponent(key)+'/dismiss');
  }
}
