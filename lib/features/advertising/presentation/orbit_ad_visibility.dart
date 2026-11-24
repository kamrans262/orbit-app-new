import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  final Stopwatch _exposure=Stopwatch();
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
    if(!_foreground)_reset();
  }
  bool _visible(){
    if(!_foreground||!mounted||ModalRoute.of(context)?.isCurrent!=true)return false;
    final object=context.findRenderObject();
    if(object is! RenderBox||!object.hasSize||
       object.size.width<=0||object.size.height<=0)return false;
    final box=MatrixUtils.transformRect(object.getTransformTo(null),Offset.zero&object.size);
    var intersection=box.intersect(Offset.zero&MediaQuery.sizeOf(context));
    // A card inside a clipped scroll viewport is not visible merely because
    // its layout bounds overlap the physical screen.
    RenderObject child=object;
    RenderObject? ancestor=child.parent;
    while(ancestor!=null){
      if(ancestor is RenderOffstage && ancestor.offstage)return false;
      final clip=ancestor.describeApproximatePaintClip(child);
      if(clip!=null){
        intersection=intersection.intersect(MatrixUtils.transformRect(
          ancestor.getTransformTo(null),clip));
      }
      child=ancestor;
      ancestor=child.parent;
    }
    if(!box.isFinite||!intersection.isFinite)return false;
    if(intersection.width<=0||intersection.height<=0)return false;
    if(intersection.width*intersection.height/(box.width*box.height)<0.5)return false;
    // Conservative occlusion check: the visible center must hit this render
    // subtree, not a modal barrier or another interactive surface.
    final hit=HitTestResult();
    RendererBinding.instance.hitTestInView(hit,intersection.center,View.of(context).viewId);
    for(final entry in hit.path){
      if(entry.target==object)return true;
      final target=entry.target;
      if(target is RenderObject){
        RenderObject? node=target;
        while(node!=null){
          if(node==object)return true;
          node=node.parent;
        }
      }
    }
    return false;
  }
  void _reset(){_exposure.stop();_exposure.reset();}
  @override
  void didUpdateWidget(covariant OrbitAdVisibility oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.minimumVisibleMs!=widget.minimumVisibleMs){
      _sent=false;_reset();
    }
  }
  void _sample(){
    if(_sent)return;
    if(!_visible()){_reset();return;}
    if(!_exposure.isRunning)_exposure.start();
    final elapsed=_exposure.elapsedMilliseconds;
    if(elapsed>=widget.minimumVisibleMs){
      _sent=true;_exposure.stop();
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
