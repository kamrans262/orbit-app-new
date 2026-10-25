import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/moments/data/orbit_m7_background_retry.dart';
import 'package:orbit_ui/features/moments/data/orbit_m7_rollout.dart';

void main(){
  test('M7 background work is inert when the release flag is off',() async {
    if(OrbitM7Rollout.enabled)return;
    var called=0;
    final ok=await OrbitM7BackgroundRetry.execute(
      verifySession:() async {
        called++;
        return OrbitRestoreState.authenticated;
      },
      resume:() async {called++;return 1;},
    );
    expect(ok,isTrue);
    expect(called,0);
  });

  test('M7 background callback rechecks trusted server session',() async {
    if(!OrbitM7Rollout.enabled)return;
    var published=0;
    Future<int> resume() async {published++;return 1;}
    final untrusted=await OrbitM7BackgroundRetry.execute(
      verifySession:()async=>OrbitRestoreState.deviceRegistration,
      resume:resume,
    );
    expect(untrusted,isTrue);
    expect(published,0);
    final offline=await OrbitM7BackgroundRetry.execute(
      verifySession:()async=>OrbitRestoreState.offlineProfile,
      resume:resume,
    );
    expect(offline,isTrue);
    expect(published,0);
    final trusted=await OrbitM7BackgroundRetry.execute(
      verifySession:()async=>OrbitRestoreState.authenticated,
      resume:resume,
    );
    expect(trusted,isTrue);
    expect(published,1);
  });

  test('M7 background network failures request retry without false receipt',
      () async {
    if(!OrbitM7Rollout.enabled)return;
    final ok=await OrbitM7BackgroundRetry.execute(
      verifySession:()async=>OrbitRestoreState.authenticated,
      resume:()async=>throw StateError('network unavailable'),
    );
    expect(ok,isFalse);
  });
}
