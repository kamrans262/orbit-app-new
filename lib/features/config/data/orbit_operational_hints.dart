import 'orbit_public_config_runtime.dart';

/// UI-only hints from the reviewed M24 bootstrap schema. Actual requests,
/// rate counters, consent and permissions are always decided by Laravel.
class OrbitOperationalHints {
  const OrbitOperationalHints(this.raw);
  final Object? raw;
  static OrbitOperationalHints get current=>OrbitOperationalHints(
    OrbitPublicConfigRuntime.instance.operationalLimitHints);
  Map? _values(String module){
    final root=raw;
    if(root is! Map||root['schema_version']!=1||root['modules'] is! Map)return null;
    final entry=(root['modules'] as Map)[module];
    if(entry is! Map||entry['revision'] is! int||(entry['revision'] as int)<1||entry['values'] is! Map)return null;
    return entry['values'] as Map;
  }
  int bound(String module,String field,int min,int max){
    final v=_values(module)?[field];
    return v is int&&v>=min&&v<=max?v:max;
  }
  bool dashboardVisible(String field){
    if(!const {'show_circles','show_people','show_moments'}.contains(field))return false;
    final root=raw;
    if(root==null)return true;
    if(root is! Map||root['schema_version']!=1||root['modules'] is! Map)return false;
    if(!(root['modules'] as Map).containsKey('dashboard'))return true;
    return _values('dashboard')?[field]==1;
  }
  int get pingPage=>bound('ping','page_size',1,30);
  int get checkInPage=>bound('check-in','page_size',1,30);
  int get checkInScopes=>bound('check-in','audience_scopes',1,25);
  int get checkInExpiryDays=>bound('check-in','expiry_days',1,30);
  int get dashboardCircles=>bound('dashboard','circle_limit',1,8);
  int get dashboardPeople=>bound('dashboard','people_limit',1,12);
  int get dashboardMoments=>bound('dashboard','moment_limit',1,3);
}
