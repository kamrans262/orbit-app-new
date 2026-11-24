import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_realtime_contract.dart';

export 'orbit_realtime_contract.dart';

/// One secondary SDK app and one session signal. Never fetch/store domain
/// content through Firebase, and never use its token for the Laravel APIs.
class OrbitRealtimeRuntime with WidgetsBindingObserver {
  OrbitRealtimeRuntime({OrbitIdentityClient? identity}):_identity=identity??OrbitIdentityClient.instance;
  static final instance=OrbitRealtimeRuntime();
  final OrbitIdentityClient _identity;
  final _events=StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get changes=>_events.stream;
  bool _started=false,_foreground=false,_busy=false;
  int _epoch=0;
  String? _owner;
  OrbitRealtimeTicket? _ticket;
  FirebaseApp? _app;
  FirebaseAuth? _auth;
  StreamSubscription<DatabaseEvent>? _watch;
  Timer? _renewal,_expiry,_retry;
  int? _revision;
  Future<void> _sdkTail=Future.value();
  Duration _poll=const Duration(seconds:25);
  Duration get pollInterval=>_poll;
  bool get connected=>_ticket!=null&&_revision!=null&&_foreground;
  bool allows(String module)=>_ticket?.modules.contains(module)==true;
  static const _name='orbit-m25-realtime';

  void start(){
    if(!OrbitRealtimeRollout.selected||_started)return;
    _started=true;
    _foreground=WidgetsBinding.instance.lifecycleState==null||
      WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if(_foreground)unawaited(_refresh());
  }

  Future<void> _sdk(Future<void> Function() action){
    final task=_sdkTail.then((_)=>action());
    _sdkTail=task.catchError((Object _){});
    return task;
  }

  bool _current(int epoch)=>_started&&_foreground&&epoch==_epoch;
  Future<void> _refresh() async {
    if(!_started||!_foreground||_busy)return;
    final epoch=_epoch;
    _busy=true;
    final clock=Stopwatch()..start();
    try{
      final owner=await _identity.currentLocalSocialOwner();
      if(!_current(epoch))return;
      if(owner==null||(_owner!=null&&owner!=_owner)){
        _owner=null;
        await _drop();
        return;
      }
      _owner=owner;
      final response=await _identity.socialRequest('POST','/realtime/bootstrap').timeout(const Duration(seconds:8));
      if(!_current(epoch)||await _identity.currentLocalSocialOwner()!=owner)return;
      final next=OrbitRealtimeTicket.parse(response,platform:defaultTargetPlatform,
        expectedProject:OrbitRealtimeRollout.project,now:DateTime.now(),requestElapsed:clock.elapsed);
      if(next==null){
        await _drop();
        return;
      }
      _poll=next.poll;
      final previous=_ticket;
      final replace=previous==null||previous.uid!=next.uid||previous.generation!=next.generation||
        previous.appId!=next.appId||previous.url!=next.url||previous.apiKey!=next.apiKey||_watch==null;
      // Never let an expired lease be renewed by a late response.
      final remaining=next.lease;
      _ticket=next;
      _expiry?.cancel();
      _expiry=Timer(remaining,(){if(_current(epoch)){unawaited(_drop());}});
      if(replace){
        _revision=null;
        await _sdk(() async {
          await _closeSdk();
          if(!_current(epoch)||!identical(_ticket,next))return;
          final app=Firebase.apps.where((a)=>a.name==_name).firstOrNull;
          final options=FirebaseOptions(apiKey:next.apiKey,appId:next.appId,
            messagingSenderId:next.sender,projectId:next.project,databaseURL:next.url,iosBundleId:next.bundle);
          if(app!=null&&(app.options.projectId!=next.project||app.options.appId!=next.appId||
            app.options.databaseURL!=next.url||app.options.apiKey!=next.apiKey)){
            await app.delete();
          }
          _app=Firebase.apps.where((a)=>a.name==_name).firstOrNull??
            await Firebase.initializeApp(name:_name,options:options);
          final auth=FirebaseAuth.instanceFor(app:_app!);
          _auth=auth;
          final db=FirebaseDatabase.instanceFor(app:_app!,databaseURL:next.url);
          db.setPersistenceEnabled(false);
          await auth.signOut();
          if(!_current(epoch)||!identical(_ticket,next))return;
          final signed=await auth.signInWithCustomToken(next.token).timeout(const Duration(seconds:10));
          if(!_current(epoch)||!identical(_ticket,next)||signed.user?.uid!=next.uid){
            await _closeSdk();return;
          }
          _watch=db.ref(next.path).onValue.listen((event){
            if(!_current(epoch)||_ticket?.generation!=next.generation)return;
            try{
              final revision=OrbitRealtimeTicket.revision(event.snapshot.value);
              if(_revision!=null&&revision<=_revision!)return;
              _revision=revision;
              _events.add(Set.unmodifiable(_ticket!.modules));
            }catch(_){unawaited(_drop());}
          },onError:(Object _){if(_current(epoch))unawaited(_drop());},cancelOnError:true);
        });
      }else if(!setEquals(previous.modules,next.modules)){
        _events.add(Set.unmodifiable({...previous.modules,...next.modules}));
      }
      if(!_current(epoch)||!identical(_ticket,next))return;
      _renewal?.cancel();
      _renewal=Timer(next.renew,()=>unawaited(_refresh()));
    }catch(_){
      if(_current(epoch))await _drop();
    }finally{
      _busy=false;
      if(_started&&_foreground&&_ticket==null)_scheduleRetry();
    }
  }

  void _scheduleRetry(){
    _retry?.cancel();
    if(_started&&_foreground)_retry=Timer(_poll,()=>unawaited(_refresh()));
  }

  Future<void> _closeSdk() async{
    final watch=_watch;_watch=null;
    try{await watch?.cancel();}catch(_){}
    final auth=_auth;_auth=null;
    try{await auth?.signOut();}catch(_){}
    final app=_app;_app=null;
    if(app!=null){try{await app.delete();}catch(_){}}
  }

  Future<void> _drop() async{
    final old=_ticket;
    _ticket=null;_revision=null;
    _renewal?.cancel();_renewal=null;
    _expiry?.cancel();_expiry=null;
    if(old!=null)_events.add(Set.unmodifiable(old.modules));
    await _sdk(_closeSdk);
    if(_started&&_foreground&&!_busy)_scheduleRetry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(!_started)return;
    if(state==AppLifecycleState.resumed){
      _foreground=true;
      unawaited(_refresh());
    }else if(_foreground){
      _foreground=false;++_epoch;
      _retry?.cancel();
      unawaited(_drop());
      // No provider request is made when the server denied the transport.
      unawaited(_disconnect());
    }
  }

  Future<void> _disconnect() async{
    try{await _identity.socialRequest('POST','/realtime/disconnect').timeout(const Duration(seconds:4));}catch(_){}
  }

  /// Called before explicit logout; never recursively HTTP-disconnect during
  /// a 401-triggered identity teardown.
  Future<void> stop({bool disconnect=false}) async{
    if(!_started)return;
    final hadLease=_ticket!=null;
    _started=false;_foreground=false;++_epoch;_owner=null;
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    await _drop();
    if(disconnect&&hadLease)await _disconnect();
  }
}
