import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/data/orbit_dashboard_repository.dart';

Map<String,dynamic> summary({
  String circlesState='ready',String momentState='disabled',
}) => <String,dynamic>{
  'schema_version':1,'generated_at':'2026-10-26T12:00:00Z',
  'viewer_policy_revision':'opaque-revision',
  'greeting':{'display_name':'The viewer'},
  'capabilities':{'circles':true,'moments':momentState=='ready',
    'plans':false,'presence':false,'ping':false,'sos':false},
  'sections':{
    'circles':{'state':circlesState,'items':circlesState=='ready' ? [
      {'id':'c1','name':'My real Circle','role':'member','member_count':2}
    ]:[]},
    'people':{'state':'ready','items':[
      {'id':'u2','display_name':'Friend','relationship':'friend','presence':null}
    ]},
    'moments':{'state':momentState,'items':[]},
    'plans':{'state':'disabled','items':[]},
    'activity':{'state':'disabled','items':[]},
    'smart_cards':{'state':'disabled','items':[]},
  },
};

void main() {
  test('M8 typed schema separates M5 Circles from M4 accepted people',(){
    final value=OrbitDashboardSnapshot.parse(summary());
    expect(value.name,'The viewer');
    expect(value.circles.items.single.name,'My real Circle');
    expect(value.circles.items.single.memberCount,2);
    expect(value.people.items.single.name,'Friend');
    expect(value.can('presence'),false);
    expect(value.plansState,DashboardState.disabled);
  });

  test('Disabled or unavailable sections do not carry protected items',(){
    final value=OrbitDashboardSnapshot.parse(summary(circlesState:'disabled'));
    expect(value.circles.state,DashboardState.disabled);
    expect(value.circles.items,isEmpty);
    final offline=OrbitDashboardSnapshot.parse(summary(circlesState:'unavailable'));
    expect(offline.circles.state,DashboardState.unavailable);
    expect(offline.circles.items,isEmpty);
  });

  test('Schema revisions and unauthenticated friend shapes fail closed',(){
    final unsupported=summary()..['schema_version']=99;
    expect(()=>OrbitDashboardSnapshot.parse(unsupported),throwsFormatException);
    final malformed=summary();
    final sections=malformed['sections'] as Map<String,dynamic>;
    final people=sections['people'] as Map<String,dynamic>;
    people['items']=[{'id':'u2','display_name':'Stranger','relationship':'none'}];
    expect(()=>OrbitDashboardSnapshot.parse(malformed),throwsFormatException);
  });
}
