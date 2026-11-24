import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/orbit_realtime_runtime.dart';

/// Route-scoped refresh, never a second data source. One in-flight operation,
/// one coalesced follow-up, and bounded fallback for visible screens.
class OrbitRealtimeRefresh {
  OrbitRealtimeRefresh({required this.modules,required this.visible,required this.refresh,
    this.fallback=false,this.invalidate,Stream<Set<String>>? changes,bool? enabled,
    Duration Function()? interval,this.minimumInterval=const Duration(seconds:3),
    this.debounce=const Duration(milliseconds:750)}):_changes=changes??OrbitRealtimeRuntime.instance.changes,
    _enabled=enabled??OrbitRealtimeRollout.selected,
    _interval=interval??(()=>OrbitRealtimeRuntime.instance.pollInterval);
  final Set<String> modules;
  final bool Function() visible;
  final Future<void> Function() refresh;
  final void Function()? invalidate;
  final bool fallback;
  final Duration minimumInterval,debounce;
  final Stream<Set<String>> _changes;
  final bool _enabled;
  final Duration Function() _interval;
  StreamSubscription<Set<String>>? _sub;
  Timer? _debounce,_poll,_cooldown;
  bool _running=false,_pending=false,_disposed=false;
  void start(){
    if(!_enabled||_disposed||_sub!=null)return;
    _sub=_changes.listen((changed){
      if(changed.intersection(modules).isNotEmpty&&visible()){
        request();
      }
    });
    if(fallback)_schedule();
  }
  void _schedule(){
    _poll=Timer(_interval(),(){
      if(_disposed)return;
      if(visible())poll();
      _schedule();
    });
  }
  /// Existing mandatory freshness timers share the same lane as RTDB events.
  /// A recent event refresh already satisfied the poll; do not duplicate it.
  void poll(){
    if(_running||_cooldown!=null||_debounce!=null)return;
    request();
  }
  void request(){
    if(_disposed||!visible())return;
    _pending=true;
    if(_running||_debounce!=null||_cooldown!=null)return;
    _debounce=Timer(debounce,(){_debounce=null;unawaited(_run());});
  }
  Future<void> _run() async{
    if(_disposed||!visible())return;
    _running=true;_pending=false;
    if(minimumInterval>Duration.zero){
      _cooldown=Timer(minimumInterval,(){_cooldown=null;if(_pending)request();});
    }
    try{invalidate?.call();await refresh();}catch(_){}
    finally{
      _running=false;
      if(_pending)request();
    }
  }
  void dispose(){
    _disposed=true;_pending=false;
    _debounce?.cancel();_poll?.cancel();_cooldown?.cancel();unawaited(_sub?.cancel());
  }

  static bool current(State state)=>state.mounted&&
    WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed&&
    ModalRoute.of(state.context)?.isCurrent==true;
}
