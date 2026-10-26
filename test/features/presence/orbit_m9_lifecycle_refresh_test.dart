import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_repository.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_rollout.dart';
import 'package:orbit_ui/features/presence/presentation/orbit_presence_runtime.dart';

void main() {
  const circle='01234567-89ab-cdef-0123-456789abcdef';
  const alice='fedcba98-7654-3210-fedc-ba9876543210';

  testWidgets('foreground Presence refreshes authorized Circle state before stale TTL',
      (tester) async {
    expect(OrbitPresenceRollout.enabled,isTrue);
    var circleReads=0;
    final repository=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path.endsWith('/presence')) {
        circleReads++;
        return {'data':{'circle_id':circle,'members':[
          if (circleReads==1) {'user_id':alice,'state':'active_now',
            'expires_at':DateTime.now().toUtc().add(const Duration(seconds:90)).toIso8601String()},
        ]}};
      }
      return {'data':{'state':'active'}};
    });
    final runtime=OrbitPresenceRuntime(repository:repository);
    final started=runtime.start();
    await tester.pump();
    await started;
    final watching=runtime.watch(circle);
    await tester.pump();
    await watching;
    expect(runtime.member(circle,alice)?.state,'active_now');
    await tester.pump(const Duration(seconds:21));
    await tester.pump();
    expect(circleReads,greaterThanOrEqualTo(2));
    expect(runtime.member(circle,alice),isNull);
    final stopped=runtime.stop();
    await tester.pump();
    await stopped;
  });

  testWidgets('foreground idle is based on touch inactivity, not network uptime',
      (tester) async {
    final states=<String>[];
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path.endsWith('/heartbeat')) states.add(body?['state'] as String);
      return {'data':{'state':'active'}};
    });
    final runtime=OrbitPresenceRuntime(repository:repo);
    final start=runtime.start();
    await tester.pump();
    await start;
    expect(states.first,'active');
    await tester.pump(const Duration(seconds:80));
    await tester.pump();
    expect(states,contains('idle'));
    runtime.recordActivity();
    await tester.pump();
    expect(states.last,'active');
    final end=runtime.stop();
    await tester.pump();
    await end;
  });

  testWidgets('unwatch prevents further snapshot reads', (tester) async {
    var reads=0;
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path.endsWith('/presence')) {reads++;return {'data':{'circle_id':circle,'members':[]}};}
      return {'data':{'state':'active'}};
    });
    final runtime=OrbitPresenceRuntime(repository:repo);
    final started=runtime.start();
    await tester.pump();
    await started;
    final watching=runtime.watch(circle);
    await tester.pump();
    await watching;
    runtime.unwatch(circle);
    final before=reads;
    await tester.pump(const Duration(seconds:25));
    await tester.pump();
    expect(reads,before);
    await runtime.stop();
  });
}
