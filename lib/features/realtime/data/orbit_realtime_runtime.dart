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
  OrbitRealtimeRuntime({OrbitIdentityClient? identity, bool? enabled,
    Future<String?> Function()? owner, Future<Map<String,dynamic>> Function(String)? bootstrap,
    Future<void> Function(String)? disconnect, OrbitRealtimeSdk? sdk})
    :_selected=enabled??OrbitRealtimeRollout.selected,
    _readOwner=owner??(identity??OrbitIdentityClient.instance).currentLocalSocialOwner,
    _bootstrap=bootstrap??((owner)=>(identity??OrbitIdentityClient.instance).realtimeRequest('/realtime/bootstrap',owner)),
    _disconnectRequest=disconnect??((owner) async {await (identity??OrbitIdentityClient.instance).realtimeRequest('/realtime/disconnect',owner);}),
    _transport=sdk??OrbitFirebaseRealtimeSdk();
  static final instance=OrbitRealtimeRuntime();
  final bool _selected;
  final Future<String?> Function() _readOwner;
  final Future<Map<String,dynamic>> Function(String) _bootstrap;
  final Future<void> Function(String) _disconnectRequest;
  final OrbitRealtimeSdk _transport;
  final _events=StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get changes=>_events.stream;
  bool _started=false,_foreground=false,_busy=false;
  int _epoch=0;
  String? _owner;
  OrbitRealtimeTicket? _ticket;
  StreamSubscription<Object?>? _watch;
  StreamSubscription<bool>? _connectionWatch;
  bool _online=false;
  Future<void>? _disconnecting;
  Timer? _renewal,_expiry,_retry;
  int? _revision;
  Future<void> _sdkTail=Future.value();
  Duration _poll=const Duration(seconds:25);
  Duration get pollInterval=>_poll;
  bool get connected=>_ticket!=null&&_revision!=null&&_foreground&&_online;
  bool allows(String module)=>_ticket?.modules.contains(module)==true;
  void start(){
    if(!_selected||_started)return;
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
      final disconnecting=_disconnecting;
      if(disconnecting!=null)await disconnecting;
      final owner=await _readOwner();
      if(!_current(epoch))return;
      if(owner==null||(_owner!=null&&owner!=_owner)){
        _owner=null;
        await _drop(notify:false);
        return;
      }
      _owner=owner;
      final response=await _bootstrap(owner).timeout(const Duration(seconds:8));
      if(!_current(epoch))return;
      final currentOwner=await _readOwner();
      if(!_current(epoch))return;
      if(currentOwner!=owner){
        _owner=null;
        await _drop(notify:false);
        return;
      }
      final next=OrbitRealtimeTicket.parse(response,platform:defaultTargetPlatform,
        expectedProject:OrbitRealtimeRollout.project,now:DateTime.now(),requestElapsed:clock.elapsed);
      if(next==null){
        await _drop();
        return;
      }
      _poll=next.poll;
      _retry?.cancel();_retry=null;
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
          await _transport.open(next);
          if(!_current(epoch)||!identical(_ticket,next)){await _transport.close();return;}
          _connectionWatch=_transport.connectivity.listen((online){
            if(!_current(epoch)||_ticket?.generation!=next.generation)return;
            final recovered=online&&!_online;
            _online=online;
            if(!online||recovered){
              _revision=null;
              _events.add(Set.unmodifiable(_ticket!.modules));
            }
          },onError:(Object _){if(_current(epoch))unawaited(_drop());});
          _watch=_transport.signals.listen((raw){
            if(!_current(epoch)||_ticket?.generation!=next.generation)return;
            try{
              final revision=OrbitRealtimeTicket.revision(raw);
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
    final connectivity=_connectionWatch;_connectionWatch=null;
    try{await connectivity?.cancel();}catch(_){}
    _online=false;
    try{await _transport.close();}catch(_){}
  }

  Future<void> _drop({bool notify=true}) async{
    final old=_ticket;
    _ticket=null;_revision=null;_online=false;
    _renewal?.cancel();_renewal=null;
    _expiry?.cancel();_expiry=null;
    if(notify&&old!=null)_events.add(Set.unmodifiable(old.modules));
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
      final hadLease=_ticket!=null;
      _foreground=false;++_epoch;
      _retry?.cancel();
      unawaited(_drop());
      // No provider request is made when the server denied the transport.
      if(hadLease&&_owner!=null)_queueDisconnect(_owner!);
    }
  }

  void _queueDisconnect(String owner){
    final task=Future<void>.sync(()=>_disconnectRequest(owner)).timeout(const Duration(seconds:8)).catchError((Object _){});
    _disconnecting=task;
    unawaited(task.whenComplete((){if(identical(_disconnecting,task))_disconnecting=null;}));
  }

  /// Called before explicit logout; never recursively HTTP-disconnect during
  /// a 401-triggered identity teardown.
  Future<void> stop({bool disconnect=false}) async{
    if(!_started)return;
    final hadLease=_ticket!=null;
    final owner=_owner;
    _started=false;_foreground=false;++_epoch;_owner=null;
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    final cleanup=_drop(notify:false);
    if(disconnect&&hadLease&&owner!=null){_queueDisconnect(owner);}
    final disconnecting=_disconnecting;
    if(disconnecting!=null)await disconnecting;
    // Local access is already fenced by epoch and lease cancellation. Never
    // block Laravel logout indefinitely on a stalled native SDK call.
    await cleanup.timeout(const Duration(seconds:5),onTimeout:(){});
  }
}


/// Small injectable boundary for deterministic tests without Firebase access.
abstract class OrbitRealtimeSdk {
  Stream<Object?> get signals;
  Stream<bool> get connectivity;
  Future<void> open(OrbitRealtimeTicket ticket);
  Future<void> close();
}

class OrbitFirebaseRealtimeSdk implements OrbitRealtimeSdk {
  static const _name='orbit-m25-realtime';
  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseDatabase? _database;
  String? _path;
  @override
  Stream<Object?> get signals=>_database!.ref(_path!).onValue.map((e)=>e.snapshot.value);
  @override
  Stream<bool> get connectivity=>_database!.ref('.info/connected').onValue.map((e)=>e.snapshot.value==true);
  @override
  Future<void> open(OrbitRealtimeTicket ticket) async{
    await close();
    final old=Firebase.apps.where((a)=>a.name==_name).firstOrNull;
    if(old!=null)await old.delete();
    final options=FirebaseOptions(apiKey:ticket.apiKey,appId:ticket.appId,
      messagingSenderId:ticket.sender,projectId:ticket.project,databaseURL:ticket.url,iosBundleId:ticket.bundle);
    _app=await Firebase.initializeApp(name:_name,options:options);
    _auth=FirebaseAuth.instanceFor(app:_app!);
    _database=FirebaseDatabase.instanceFor(app:_app!,databaseURL:ticket.url);
    _database!.setPersistenceEnabled(false);
    await _auth!.signOut();
    final result=await _auth!.signInWithCustomToken(ticket.token);
    if(result.user?.uid!=ticket.uid)throw const FormatException('Realtime identity mismatch.');
    _path=ticket.path;
  }
  @override
  Future<void> close() async{
    final db=_database;_database=null;_path=null;
    try{await db?.goOffline();}catch(_){}
    final auth=_auth;_auth=null;
    try{await auth?.signOut();}catch(_){}
    final app=_app;_app=null;
    if(app!=null){try{await app.delete();}catch(_){}}
  }
}
