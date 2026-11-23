import 'dart:async';
import 'package:flutter/material.dart';

/// Invisible measurement-only wrapper; preserves exact original card visuals.
class OrbitAdVisibility extends StatefulWidget {
  const OrbitAdVisibility({required this.child,required this.minimumVisibleMs,
    required this.onVisible,super.key});
  final Widget child;
  final int minimumVisibleMs;
  final ValueChanged<int> onVisible;
  @override
  State<OrbitAdVisibility> createState()=>_OrbitAdVisibilityState();
}

class _OrbitAdVisibilityState extends State<OrbitAdVisibility>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _since;
  bool _sent=false,_foreground=true;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer=Timer.periodic(const Duration(milliseconds:250),(_)=>_sample());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    _foreground=state==AppLifecycleState.resumed;
    if(!_foreground)_since=null;
  }
  bool _visible(){
    if(!_foreground||!mounted||ModalRoute.of(context)?.isCurrent!=true)return false;
    final object=context.findRenderObject();
    if(object is! RenderBox||!object.hasSize||
       object.size.width<=0||object.size.height<=0)return false;
    final origin=object.localToGlobal(Offset.zero);
    final box=origin&object.size;
    final viewport=Offset.zero&MediaQuery.sizeOf(context);
    final intersection=box.intersect(viewport);
    if(intersection.width<=0||intersection.height<=0)return false;
    return intersection.width*intersection.height/(box.width*box.height)>=0.5;
  }
  void _sample(){
    if(_sent)return;
    if(!_visible()){_since=null;return;}
    final now=DateTime.now();
    _since??=now;
    final elapsed=now.difference(_since!).inMilliseconds;
    if(elapsed>=widget.minimumVisibleMs){
      _sent=true;
      widget.onVisible(elapsed);
    }
  }
  @override
  void dispose(){
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>widget.child;
}
