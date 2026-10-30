import 'dart:async';

import 'package:flutter/material.dart';

/// Sends a read receipt only after one message is actually on screen for
/// 700ms, not merely because a ListView prefetched it offscreen. Never emits
/// an event for an offstage route or a fast scroll past a bubble.
class OrbitMessageVisibilityObserver extends StatefulWidget {
  const OrbitMessageVisibilityObserver({
    required this.child,required this.onDwell,super.key,
  });
  final Widget child;
  final VoidCallback onDwell;

  @override
  State<OrbitMessageVisibilityObserver> createState()=>
    _OrbitMessageVisibilityObserverState();
}
class _OrbitMessageVisibilityObserverState
    extends State<OrbitMessageVisibilityObserver> {
  ScrollPosition? _position;
  Timer? _dwell;
  bool _notified=false;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)_schedule();
    });
  }
  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    final next=Scrollable.maybeOf(context)?.position;
    if(_position!=next){
      _position?.removeListener(_schedule);
      _position=next;
      _position?.addListener(_schedule);
    }
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)_schedule();
    });
  }
  @override
  void dispose(){
    _dwell?.cancel();
    _position?.removeListener(_schedule);
    super.dispose();
  }

  void _schedule(){
    if(_notified||!mounted)return;
    _dwell?.cancel();
    _dwell=Timer(const Duration(milliseconds:700),(){
      if(!mounted||_notified||!_isVisible())return;
      _notified=true;
      widget.onDwell();
    });
  }
  bool _isVisible(){
    if(ModalRoute.of(context)?.isCurrent!=true)return false;
    final render=context.findRenderObject();
    if(render is! RenderBox||!render.attached||
        render.size.isEmpty)return false;
    final top=render.localToGlobal(Offset.zero).dy;
    final media=MediaQuery.of(context);
    final safeTop=media.padding.top+62;
    final safeBottom=media.size.height-media.viewInsets.bottom-90;
    if(safeBottom<=safeTop)return false;
    final low=top.clamp(safeTop,safeBottom);
    final high=(top+render.size.height).clamp(safeTop,safeBottom);
    return (high-low)/render.size.height>=0.55;
  }

  @override
  Widget build(BuildContext context)=>widget.child;
}
