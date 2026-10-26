import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_repository.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_rollout.dart';
import 'package:orbit_ui/features/presence/presentation/orbit_presence_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const circle='01234567-89ab-cdef-0123-456789abcdef';
  const alice='fedcba98-7654-3210-fedc-ba9876543210';

  test('refresh of watched Circle replaces stale Presence with current server result',
      () async {
    expect(OrbitPresenceRollout.enabled,isTrue);
    var circleReads=0;
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path.endsWith('/presence')) {
        circleReads++;
        return {'data':{'circle_id':circle,'members':[
          if (circleReads==1)
            {'user_id':alice,'state':'active_now',
             'expires_at':DateTime.now().toUtc()
                 .add(const Duration(seconds:90)).toIso8601String()},
        ]}};
      }
      return {'data':{'state':'active'}};
    });
    final runtime=OrbitPresenceRuntime(repository:repo);
    try {
      await runtime.start();
      await runtime.watch(circle);
      expect(runtime.member(circle,alice)?.state,'active_now');
      await runtime.refreshWatched();
      expect(circleReads,2);
      expect(runtime.member(circle,alice),isNull);
    } finally {
      await runtime.stop();
    }
  });

  test('idle follows 60 seconds of inactivity and active resumes on interaction',
      () async {
    var current=DateTime.utc(2026,10,26,12);
    final states=<String>[];
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path.endsWith('/heartbeat')) states.add(body?['state'] as String);
      return {'data':{'state':'active'}};
    });
    final runtime=OrbitPresenceRuntime(repository:repo,clock:()=>current);
    try {
      await runtime.start();
      expect(states.last,'active');
      current=current.add(const Duration(seconds:61));
      await runtime.heartbeatNow();
      expect(states.last,'idle');
      runtime.recordActivity();
      await runtime.heartbeatNow();
      expect(states.last,'active');
    } finally {
      await runtime.stop();
    }
  });

  test('unwatch stops further revalidation and rejects removed Circle', () async {
    var reads=0;
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path.endsWith('/presence')) {
        reads++;
        return {'data':{'circle_id':circle,'members':[]}};
      }
      return {'data':{'state':'active'}};
    });
    final runtime=OrbitPresenceRuntime(repository:repo);
    try {
      await runtime.start();
      await runtime.watch(circle);
      runtime.unwatch(circle);
      await runtime.refreshWatched();
      expect(reads,1);
      expect(runtime.member(circle,alice),isNull);
    } finally {
      await runtime.stop();
    }
  });
}
