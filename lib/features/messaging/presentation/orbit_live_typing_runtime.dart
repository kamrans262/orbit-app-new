import 'dart:async';
import '../../realtime/data/orbit_realtime_runtime.dart';

/// Independent HTTPS typing projection. RTDB never contains participant IDs.
/// The server's five-second maximum is also enforced locally; a delayed
/// response or permission change cannot resurrect a stale typing indicator.
class OrbitLiveTypingRuntime {
  OrbitLiveTypingRuntime({required this.read,required this.scope,
    required this.visible,required this.onChanged,
    Stream<Set<String>>? changes,bool? selected,bool Function()? connected})
      :_changes=changes??OrbitRealtimeRuntime.instance.changes,
       _selected=selected??OrbitRealtimeRollout.selected,
       _connected=connected??(()=>OrbitRealtimeRuntime.instance.connected&&
           OrbitRealtimeRuntime.instance.allows('messaging'));
  final Future<Map<String,dynamic>> Function(String) read;
  final String? Function() scope;
  final bool Function() visible;
  final void Function(Set<String>) onChanged;
  final Stream<Set<String>> _changes;
  final bool _selected;
  final bool Function() _connected;
  StreamSubscription<Set<String>>? _sub;
  Timer? _poll,_expiry,_debounce;
  bool _busy=false,_pending=false,_closed=false;
  int _epoch=0;

  void start(){
    if(_closed||_poll!=null)return;
    if(_selected){
      _sub=_changes.listen((modules){
        if(modules.intersection(const {'messaging','circles','social'}).isNotEmpty){
          // Hide the previous projection until Laravel confirms current access.
          if(visible()){clear();request();}
        }
      });
    }
    _poll=Timer.periodic(const Duration(seconds:4),(_){
      if(!visible()){clear();return;}
      if(!_selected||!_connected()){request();}
    });
    request();
  }
  void request(){
    if(_closed||!visible()||scope()==null){return;}
    _pending=true;
    if(_busy||_debounce!=null){return;}
    _debounce=Timer(const Duration(milliseconds:250),(){
      _debounce=null;unawaited(_refresh());
    });
  }
  Future<void> _refresh() async{
    if(_closed||!visible()){return;}
    final id=scope();
    if(id==null){return;}
    final epoch=_epoch;
    _busy=true;_pending=false;
    final clock=Stopwatch()..start();
    try{
      final result=await read(id).timeout(const Duration(seconds:5));
      if(_closed||epoch!=_epoch||!visible()||scope()!=id){return;}
      final ids=result['typing_user_ids'];
      final ttl=result['ttl_seconds'];
      if(ids is! List||ids.length>200||ids.any((v)=>v is! String||v.isEmpty)||
        ttl is! int||ttl<1||ttl>5){
        clear();return;
      }
      final remaining=Duration(seconds:ttl)-clock.elapsed;
      if(remaining<=Duration.zero){clear();return;}
      _expiry?.cancel();
      onChanged(Set.unmodifiable(ids.cast<String>()));
      _expiry=Timer(remaining,clear);
    }catch(_){
      if(!_closed&&epoch==_epoch){clear();}
    }finally{
      _busy=false;
      if(_pending){request();}
    }
  }
  void clear(){
    ++_epoch;_expiry?.cancel();_expiry=null;
    if(!_closed){onChanged(const <String>{});}
  }
  void dispose(){
    _closed=true;++_epoch;
    _poll?.cancel();_expiry?.cancel();_debounce?.cancel();
    unawaited(_sub?.cancel());
  }
}
