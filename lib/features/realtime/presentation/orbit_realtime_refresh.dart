import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/orbit_realtime_runtime.dart';

/// Route-scoped refresh, never a second data source. One in-flight operation,
/// one coalesced follow-up, and bounded fallback for visible screens.
class OrbitRealtimeRefresh {
  OrbitRealtimeRefresh({required this.modules,required this.visible,required this.refresh,
    this.fallback=false,this.invalidate});
  final Set<String> modules;
  final bool Function() visible;
  final Future<void> Function() refresh;
  final void Function()? invalidate;
  final bool fallback;
  StreamSubscription<Set<String>>? _sub;
  Timer? _debounce,_poll;
  bool _running=false,_pending=false,_disposed=false;
  void start(){
    if(!OrbitRealtimeRollout.selected||_disposed)return;
    _sub=OrbitRealtimeRuntime.instance.changes.listen((changed){
      if(changed.intersection(modules).isNotEmpty&&visible()){
        invalidate?.call();
        request();
      }
    });
    if(fallback)_schedule();
  }
  void _schedule(){
    _poll=Timer(OrbitRealtimeRuntime.instance.pollInterval,(){
      if(_disposed)return;
      if(visible())request();
      _schedule();
    });
  }
  void request(){
    if(_disposed||!visible())return;
    _pending=true;
    if(_running||_debounce!=null)return;
    _debounce=Timer(const Duration(milliseconds:750),(){_debounce=null;unawaited(_run());});
  }
  Future<void> _run() async{
    if(_disposed||!visible())return;
    _running=true;_pending=false;
    try{await refresh();}catch(_){}
    finally{
      _running=false;
      if(_pending)request();
    }
  }
  void dispose(){
    _disposed=true;_pending=false;
    _debounce?.cancel();_poll?.cancel();unawaited(_sub?.cancel());
  }

  static bool current(State state)=>state.mounted&&
    WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed&&
    ModalRoute.of(state.context)?.isCurrent==true;
}
