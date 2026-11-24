import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/realtime/data/orbit_realtime_runtime.dart';
import 'package:orbit_ui/features/realtime/presentation/orbit_realtime_refresh.dart';
import 'package:orbit_ui/features/messaging/presentation/orbit_live_typing_runtime.dart';
import 'package:orbit_ui/features/check_in/presentation/navigation/orbit_check_in_navigation.dart';

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

// Run transport async work on the real Dart event loop, while explicitly
// firing the scheduled renewal/expiry callbacks. No ten-minute fake-async hang.
class ManualTimer implements Timer{
  ManualTimer(this.duration,this.callback,{this.repeating=false});
  final Duration duration;
  final void Function() callback;
  final bool repeating;
  bool _active=true;
  int _tick=0;
  @override bool get isActive=>_active;
  @override int get tick=>_tick;
  @override void cancel(){_active=false;}
  void fire(){
    if(!_active){return;}
    _tick++;
    if(!repeating){_active=false;}
    callback();
  }
}
class ManualTimers{
  final scheduled=<ManualTimer>[];
  Timer once(Duration delay,void Function() callback){
    final timer=ManualTimer(delay,callback);scheduled.add(timer);return timer;
  }
  Timer periodic(Duration delay,void Function(Timer) callback){
    late final ManualTimer timer;
    timer=ManualTimer(delay,()=>callback(timer),repeating:true);
    scheduled.add(timer);return timer;
  }
  ManualTimer active(Duration delay)=>scheduled.lastWhere((t)=>t.isActive&&t.duration==delay);
  ManualTimer expiry()=>scheduled.lastWhere((t)=>t.isActive&&t.duration>const Duration(seconds:4)&&t.duration<=const Duration(seconds:5));
}
Future<void> settle() async{
  // Flush native-free async callbacks, stream events and Future chaining.
  for(var i=0;i<4;i++){await Future<void>.delayed(Duration.zero);}
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
  test('one subscription, deduplication, renewal, lifecycle stop',() async{
    final sdk=FakeSdk(),timers=ManualTimers();
    var calls=0,disconnects=0;
    final runtime=OrbitRealtimeRuntime(enabled:true,sdk:sdk,owner:() async=>'a',
      bootstrap:(_) async{calls++;return response();},
      disconnect:(_) async{disconnects++;},timer:timers.once);
    final seen=<Set<String>>[];final sub=runtime.changes.listen(seen.add);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    try{
      runtime.start();runtime.start();await settle();
      expect(calls,1);expect(sdk.opened,1);
      sdk.online.add(true);sdk.revisions.add({'schema_version':1,'revision':1});await settle();
      expect(runtime.connected,true);
      sdk.online.add(false);await settle();expect(runtime.connected,false);
      sdk.online.add(true);await settle();expect(runtime.connected,true);
      final count=seen.length;
      sdk.revisions.add({'schema_version':1,'revision':1});
      sdk.revisions.add({'schema_version':1,'revision':2});
      await settle();expect(seen.length,count+1);
      timers.active(const Duration(seconds:30)).fire();await settle();
      expect(calls,2);expect(sdk.opened,1);
      await runtime.stop(disconnect:true).timeout(const Duration(seconds:15));
      expect(runtime.connected,false);expect(disconnects,1);
      expect(sdk.closed,greaterThanOrEqualTo(2));
      expect(sdk.online.hasListener,false);expect(sdk.revisions.hasListener,false);
      expect(timers.scheduled.any((timer)=>timer.isActive),false);
      final after=seen.length;
      sdk.revisions.add({'schema_version':1,'revision':3});await settle();
      expect(seen.length,after);
    }finally{
      await runtime.stop();await sub.cancel();await sdk.dispose();
    }
  });
  testWidgets('late bootstrap cannot attach SDK after logout',(tester) async{
    final sdk=FakeSdk();final gate=Completer<Map<String,dynamic>>();
    final runtime=OrbitRealtimeRuntime(enabled:true,sdk:sdk,owner:() async=>'a',bootstrap:(_)=>gate.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    runtime.start();await tester.pump();
    var stopped=false;
    unawaited(runtime.stop().then((_)=>stopped=true));
    await tester.pump();expect(stopped,true);
    gate.complete(response());await tester.pump();
    expect(sdk.opened,0);await sdk.dispose();
  });
  testWidgets('route refresh coalesces bursts, ignores hidden routes and stops',(tester) async{
    final changes=StreamController<Set<String>>.broadcast();
    var visible=true,calls=0;final gate=Completer<void>();
    final binding=OrbitRealtimeRefresh(modules:const {'location'},visible:()=>visible,
      refresh:() async{calls++;if(calls==1)await gate.future;},enabled:true,changes:changes.stream,minimumInterval:Duration.zero)..start();
    for(var i=0;i<10;i++){changes.add({'location'});}
    await tester.pump();await tester.pump(const Duration(seconds:1));expect(calls,1);
    for(var i=0;i<10;i++){changes.add({'location'});}
    await tester.pump();gate.complete();await tester.pump();await tester.pump(const Duration(seconds:1));
    expect(calls,2);
    visible=false;changes.add({'location'});await tester.pump(const Duration(seconds:1));expect(calls,2);
    binding.dispose();visible=true;changes.add({'location'});await tester.pump(const Duration(seconds:1));
    expect(calls,2);await changes.close();
  });

  testWidgets('periodic poll shares the event lane and respects cooldown',(tester) async{
    final changes=StreamController<Set<String>>.broadcast();
    var calls=0;
    final binding=OrbitRealtimeRefresh(modules:const {'location'},visible:()=>true,
      refresh:() async{calls++;},enabled:true,changes:changes.stream,
      minimumInterval:const Duration(seconds:3))..start();
    changes.add({'location'});binding.poll();
    await tester.pump();await tester.pump(const Duration(seconds:1));
    expect(calls,1);
    for(var i=0;i<20;i++){binding.poll();changes.add({'location'});}
    await tester.pump();await tester.pump(const Duration(seconds:1));
    expect(calls,1);
    await tester.pump(const Duration(seconds:3));await tester.pump(const Duration(seconds:1));
    expect(calls,2);
    binding.dispose();await changes.close();
  });

  test('typing signals reauthorize, expire and fall back only when needed',() async{
    final changes=StreamController<Set<String>>.broadcast();
    final timers=ManualTimers();
    var connected=true,visible=true,calls=0;
    String? scope='circle-thread';
    Set<String> ids={};
    final typing=OrbitLiveTypingRuntime(read:(id) async{
        expect(id,'circle-thread');calls++;
        return {'typing_user_ids':['member'],'ttl_seconds':5};
      },scope:()=>scope,visible:()=>visible,onChanged:(value)=>ids=value,
      changes:changes.stream,selected:true,connected:()=>connected,
      timer:timers.once,periodic:timers.periodic)..start();
    try{
      timers.active(const Duration(milliseconds:250)).fire();await settle();
      expect(calls,1);expect(ids,{'member'});
      timers.active(const Duration(seconds:4)).fire();await settle();expect(calls,1);
      timers.expiry().fire();expect(ids,isEmpty);
      changes.add({'messaging'});await settle();
      timers.active(const Duration(milliseconds:250)).fire();await settle();
      expect(ids,{'member'});expect(calls,2);
      connected=false;
      timers.active(const Duration(seconds:4)).fire();
      timers.active(const Duration(milliseconds:250)).fire();await settle();
      expect(calls,3);
      visible=false;scope=null;
      timers.active(const Duration(seconds:4)).fire();expect(ids,isEmpty);expect(calls,3);
    }finally{typing.dispose();await changes.close();}
    expect(timers.scheduled.any((timer)=>timer.isActive),false);
  });

  testWidgets('late typing result cannot restore a revoked Circle scope',(tester) async{
    final changes=StreamController<Set<String>>.broadcast();
    final gate=Completer<Map<String,dynamic>>();
    String? scope='circle-thread';Set<String> ids={};
    final typing=OrbitLiveTypingRuntime(read:(_)=>gate.future,
      scope:()=>scope,visible:()=>true,onChanged:(value)=>ids=value,
      changes:changes.stream,selected:true,connected:()=>true)..start();
    await tester.pump(const Duration(milliseconds:300));
    scope=null;typing.clear();
    gate.complete({'typing_user_ids':['member'],'ttl_seconds':5});
    await tester.pump();expect(ids,isEmpty);
    typing.dispose();await changes.close();
  });

  testWidgets('existing Check-In sheet refreshes history and hides a changed account',(tester) async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final changes=StreamController<Set<String>>.broadcast();
    var owner='a',history='Accepted';
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OrbitCheckInLiveSheet<String>(
      initial:history,selected:true,owner:() async=>owner,changes:changes.stream,
      load:() async=>history,content:(_,value)=>Text(value)))));
    await tester.pump(const Duration(seconds:1));await tester.pump();
    expect(find.text('Accepted'),findsOneWidget);
    history='Withdrawn';changes.add({'check_in'});
    await tester.pump();await tester.pump(const Duration(seconds:4));await tester.pump();
    expect(find.text('Withdrawn'),findsOneWidget);
    owner='b';changes.add({'check_in'});
    await tester.pump();await tester.pump(const Duration(seconds:4));await tester.pump();
    expect(find.text('Withdrawn'),findsNothing);
    expect(find.text('Check-In access could not be verified. Reconnect to refresh.'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await changes.close();
  });
}
