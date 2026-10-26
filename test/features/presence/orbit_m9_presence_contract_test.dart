import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_models.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_repository.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_rollout.dart';

void main() {
  test('M9 disabled by default, no arbitrary socket endpoint', () {
    expect(OrbitPresenceRollout.enabled,false);
    expect(OrbitPresenceRollout.secureGateway,isNull);
  });

  test('reject malformed Presence payloads and expired leases', () {
    final t=DateTime.utc(2026,10,26,12);
    expect(() => OrbitPresenceSnapshot.fromJson({'members':[]},now:t),
      throwsFormatException);
    final snapshot=OrbitPresenceSnapshot.fromJson({
      'circle_id':'circle-a',
      'members':[
        {'user_id':'old','state':'active_now',
          'expires_at':t.subtract(const Duration(seconds:1)).toIso8601String()},
        {'user_id':'new','state':'idle',
          'expires_at':t.add(const Duration(seconds:90)).toIso8601String()},
      ],
    },now:t);
    expect(snapshot.member('old',t),isNull);
    expect(snapshot.member('new',t)?.labelAt(t),'Idle');
    expect(snapshot.member('new',t.add(const Duration(seconds:31))),isNull);
  });

  test('Ghost Mode and Nobody global settings are fail-closed', () {
    final settings=OrbitPresencePreferences.fromJson({
      'global':{'ghost_mode_enabled':true,'presence_visibility':'My Circle'},
      'circles':[{'circle_id':'c','requested':true,'duration':'persistent'}],
    });
    expect(settings.globalPermitsPresence,false);
    expect(settings.forCircle('c')?.requested,true);
    expect(settings.forCircle('elsewhere'),isNull);
  });

  test('Circle HTTP requests are scoped and never cached locally', () async {
    final calls=<String>[];
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      calls.add('$method $path');
      if (path.endsWith('/presence')) return {
        'data':{'circle_id':'01234567-89ab-cdef-0123-456789abcdef','members':[]}};
      if (path.endsWith('/settings')) return {'data':{
        'global':{'ghost_mode_enabled':true,'presence_visibility':'Nobody'},
        'circles':[]}};
      return {'data':{'requested':false}};
    });
    const id='01234567-89ab-cdef-0123-456789abcdef';
    await repo.circle(id);
    await repo.preferences();
    await repo.heartbeat('active');
    await repo.disconnect();
    await repo.circleConsent(id,enabled:false);
    expect(calls,[
      'GET /circles/$id/presence','GET /me/presence/settings',
      'POST /presence/heartbeat','POST /presence/disconnect',
      'PUT /me/presence/circles/$id',
    ]);
    expect(() => repo.circle('../../other'),throwsFormatException);
    expect(() => repo.heartbeat('fake'),throwsArgumentError);
  });

  test('24h consent request requires explicit duration and future expiry', () async {
    Map<String,Object?>? last;
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      last=body;
      return {'data':{'requested':true}};
    });
    const id='01234567-89ab-cdef-0123-456789abcdef';
    final until=DateTime.now().toUtc().add(const Duration(hours:24));
    await repo.circleConsent(id,enabled:true,duration:'until_expiry',expiresAt:until);
    expect(last?['duration'],'until_expiry');
    expect(last?['expires_at'],until.toIso8601String());
    await expectLater(repo.circleConsent(id,enabled:true,duration:'bad'),
      throwsFormatException);
  });
}
