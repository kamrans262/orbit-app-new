import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_repository.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_snapshot.dart';
import 'package:orbit_ui/features/circles/presentation/screens/orbit_live_circles_screen.dart';

class _FakeCircles extends OrbitCircleRepository {
  _FakeCircles({this.fail=false, this.archiveEnabled=false});
  final bool fail;
  final bool archiveEnabled;
  @override
  Future<OrbitCirclePage<OrbitCircle>> archived({int page=1}) async {
    if(!archiveEnabled) throw OrbitIdentityException('Feature disabled',404);
    return const OrbitCirclePage<OrbitCircle>([],1,false);
  }
  @override
  Future<OrbitCirclePage<OrbitCircle>> list({int page=1}) async {
    if(fail) throw OrbitIdentityException('No connection');
    return const OrbitCirclePage<OrbitCircle>([
      OrbitCircle(
        id:'c1',name:'Actual Server Circle',ownerId:'u1',
        role:'owner',memberCount:2,revision:3,
      )
    ],1,false);
  }
}
class _FakeStore extends OrbitCircleSnapshotStore {
  @override
  Future<void> save(List<OrbitCircle> circles) async {}
  @override
  Future<OrbitCircleSnapshot?> read() async=>
    OrbitCircleSnapshot(const [
      OrbitCircle(id:'c1',name:'Cached Circle',ownerId:'',
        role:'offline',memberCount:0,revision:0)
    ],DateTime.now());
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('live list renders actual server Circle, never M4 demo',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home:OrbitLiveCirclesScreen(
        repository:_FakeCircles(),store:_FakeStore())));
      await tester.pumpAndSettle();
      expect(find.text('Actual Server Circle'),findsOneWidget);
      expect(find.text('Archived'),findsNothing);
      expect(find.text('Best Friends'),findsNothing);
      expect(find.textContaining('OFFLINE'),findsNothing);
  });
  testWidgets('archived shortcut appears only if backend feature is enabled',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home:OrbitLiveCirclesScreen(
        repository:_FakeCircles(archiveEnabled:true),store:_FakeStore())));
      await tester.pumpAndSettle();
      expect(find.text('Archived'),findsOneWidget);
  });
  testWidgets('offline fallback is clearly read-only and never simulates roster',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home:OrbitLiveCirclesScreen(
        repository:_FakeCircles(fail:true),store:_FakeStore())));
      await tester.pumpAndSettle();
      expect(find.text('Cached Circle'),findsOneWidget);
      expect(find.textContaining('OFFLINE'),findsOneWidget);
      expect(find.textContaining('0 members'),findsNothing);
  });
}
