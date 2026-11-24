import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/realtime/data/orbit_realtime_runtime.dart';
import 'package:orbit_ui/features/realtime/presentation/orbit_realtime_refresh.dart';

const uid='00000000-0000-4000-8000-000000000001';
const generation='00000000-0000-4000-8000-000000000002';
Map<String,dynamic> response({String project='orbit-app-4cb36',String? url,
  int expirySeconds=60,String? path,List<String> modules=const ['presence','location']})=>
  {'data':{'schema_version':1,'enabled':true,'transport':'firebase_rtdb','uid':uid,
    'generation':generation,'signal_path':path??'orbit_m25/sessions/$uid/signal','custom_token':'synthetic-token',
    'firebase':{'project_id':project,'database_url':url??'https://$project-default-rtdb.firebaseio.com',
      'api_key':'synthetic-key','sender_id':'123','app_id':'1:123:android:abcd'},
    'lease_until_ms':DateTime.now().add(Duration(seconds:expirySeconds)).millisecondsSinceEpoch,
    'renew_after_seconds':30,'fallback_min_poll_seconds':25,'modules':modules}};
OrbitRealtimeTicket? parse(Map<String,dynamic> data,{Duration elapsed=Duration.zero})=>
  OrbitRealtimeTicket.parse(data,platform:TargetPlatform.android,
    expectedProject:'orbit-app-4cb36',now:DateTime.now(),requestElapsed:elapsed);

class FakeSdk implements OrbitRealtimeSdk{
  final revisions=StreamController<Object?>.broadcast();
  final online=StreamController<bool>.broadcast();
  int opened=0,closed=0;
  @override Stream<Object?> get signals=>revisions.stream;
  @override Stream<bool> get connectivity=>online.stream;
  @override Future<void> open(OrbitRealtimeTicket ticket) async{opened++;}
  @override Future<void> close() async{closed++;}
  Future<void> dispose() async{await revisions.close();await online.close();}
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('strict project, origin, session, schema and lease validation',(){
    expect(parse(response())!.uid,uid);
    expect(parse(response(),elapsed:const Duration(seconds:10))!.lease.inSeconds,lessThanOrEqualTo(50));
    expect(()=>parse(response(project:'another-project')),throwsFormatException);
    expect(()=>parse(response(url:'https://evil.firebaseio.com')),throwsFormatException);
    expect(()=>parse(response(url:'https://orbit-app-4cb36-default-rtdb.firebaseio.com/private')),throwsFormatException);
    expect(()=>parse(response(path:'orbit_m25/sessions/other/signal')),throwsFormatException);
    expect(()=>parse(response(expirySeconds:-1)),throwsFormatException);
    expect(()=>parse(response(modules:['unknown'])),throwsFormatException);
    expect(parse({'data':{'schema_version':1,'enabled':false,'transport':'https'}}),isNull);
    expect(OrbitRealtimeTicket.revision({'schema_version':1,'revision':7}),7);
    expect(()=>OrbitRealtimeTicket.revision({'schema_version':1,'revision':7,'lat':1}),throwsFormatException);
  });
  testWidgets('disabled build performs no bootstrap or SDK work',(tester) async{
    final sdk=FakeSdk();var calls=0;
    final runtime=OrbitRealtimeRuntime(enabled:false,sdk:sdk,owner:() async=>'a',
      bootstrap:(_) async{calls++;return response();});
    runtime.start();await tester.pump();
    expect(calls,0);expect(sdk.opened,0);
    await runtime.stop();await sdk.dispose();
  });
  testWidgets('one subscription, deduplication, renewal, lifecycle stop',(tester) async{
    final sdk=FakeSdk();var calls=0,disconnects=0;
    final runtime=OrbitRealtimeRuntime(enabled:true,sdk:sdk,owner:() async=>'a',
      bootstrap:(_) async{calls++;return response();},
      disconnect:(_) async{disconnects++;});
    final seen=<Set<String>>[];final sub=runtime.changes.listen(seen.add);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    runtime.start();runtime.start();
    await tester.pump();await tester.pump();
    expect(calls,1);expect(sdk.opened,1);
    sdk.online.add(true);await tester.pump();
    sdk.revisions.add({'schema_version':1,'revision':1});await tester.pump();
    expect(runtime.connected,true);
    final count=seen.length;
    sdk.revisions.add({'schema_version':1,'revision':1});
    sdk.revisions.add({'schema_version':1,'revision':2});
    await tester.pump();expect(seen.length,count+1);
    await tester.pump(const Duration(seconds:31));
    await tester.pump();expect(calls,2);expect(sdk.opened,1);
    await runtime.stop(disconnect:true);await tester.pump();
    expect(runtime.connected,false);expect(disconnects,1);
    final after=seen.length;
    sdk.revisions.add({'schema_version':1,'revision':3});
    await tester.pump();expect(seen.length,after);
    await sub.cancel();await sdk.dispose();
  });
  testWidgets('late bootstrap cannot attach SDK after logout',(tester) async{
    final sdk=FakeSdk();final gate=Completer<Map<String,dynamic>>();
    final runtime=OrbitRealtimeRuntime(enabled:true,sdk:sdk,owner:() async=>'a',bootstrap:(_)=>gate.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    runtime.start();await tester.pump();
    await runtime.stop();gate.complete(response());await tester.pump();
    expect(sdk.opened,0);await sdk.dispose();
  });
  testWidgets('route refresh coalesces bursts, ignores hidden routes and stops',(tester) async{
    final changes=StreamController<Set<String>>.broadcast();
    var visible=true,calls=0;final gate=Completer<void>();
    final binding=OrbitRealtimeRefresh(modules:const {'location'},visible:()=>visible,
      refresh:() async{calls++;if(calls==1)await gate.future;},enabled:true,changes:changes.stream)..start();
    for(var i=0;i<10;i++){changes.add({'location'});}
    await tester.pump();await tester.pump(const Duration(seconds:1));expect(calls,1);
    for(var i=0;i<10;i++){changes.add({'location'});}
    await tester.pump();gate.complete();await tester.pump();await tester.pump(const Duration(seconds:1));
    expect(calls,2);
    visible=false;changes.add({'location'});await tester.pump(const Duration(seconds:1));expect(calls,2);
    binding.dispose();visible=true;changes.add({'location'});await tester.pump(const Duration(seconds:1));
    expect(calls,2);await changes.close();
  });
}
