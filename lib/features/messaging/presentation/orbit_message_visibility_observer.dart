import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    // The scroll viewport already excludes chat headers, composers, safe
    // areas, and any other layout constraints. Hardcoded screen insets can
    // suppress legitimate read receipts on small devices and in widget tests.
    if(ModalRoute.of(context)?.isCurrent!=true)return false;
    final render=context.findRenderObject();
    if(render is! RenderBox||!render.attached||render.size.isEmpty)return false;

    // The viewport interface is not a RenderBox; its underlying render
    // object usually is. Promote the concrete object before accessing
    // layout metrics (Flutter 3.47 static analyzer compatibility).
    final Object? viewportObject=RenderAbstractViewport.of(render);
    if(viewportObject is! RenderBox ||
        !viewportObject.attached || viewportObject.size.isEmpty){
      return false;
    }
    final messageRect=render.localToGlobal(Offset.zero)&render.size;
    final viewportRect=viewportObject.localToGlobal(Offset.zero)&
      viewportObject.size;
    final screenRect=Offset.zero&MediaQuery.sizeOf(context);
    final visibleRect=messageRect.intersect(viewportRect).intersect(screenRect);
    if(visibleRect.isEmpty||messageRect.width<=0||messageRect.height<=0){
      return false;
    }
    final fraction=(visibleRect.width*visibleRect.height)/
        (messageRect.width*messageRect.height);
    return fraction>=0.55;
  }

  @override
  Widget build(BuildContext context)=>widget.child;
}
