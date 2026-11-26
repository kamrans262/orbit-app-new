import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Playback is local-only: no publish, unencrypted network stream or automatic
/// remote upload. The camera owns and deletes the temporary capture.
class OrbitMomentDraftPlayer extends StatefulWidget {
  const OrbitMomentDraftPlayer({
    required this.file,required this.kind,required this.muted,this.active=true,super.key,
  });
  final File file;
  final String kind;
  final bool muted,active;
  @override
  State<OrbitMomentDraftPlayer> createState()=>_OrbitMomentDraftPlayerState();
}

class _OrbitMomentDraftPlayerState extends State<OrbitMomentDraftPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  StreamSubscription<void>? _ended;
  bool _busy=true,_playing=false;
  bool _valid=false;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }
  Future<void> _init() async {
    // A missing/expired local clip must not start a native playback channel.
    if(!await widget.file.exists()||!mounted){
      if(mounted)setState((){
        _busy=false;_valid=false;
      });
      return;
    }
    try{
      if(widget.kind=='video'){
        final video=VideoPlayerController.file(widget.file);
        _video=video;
        await video.initialize();
        if(!mounted||_video!=video)return;
        await video.setVolume(widget.muted?0:1);
        video.addListener(_videoChanged);
      }else{
        final audio=AudioPlayer();
        _audio=audio;
        _ended=audio.onPlayerComplete.listen((_){
          if(mounted)setState(()=>_playing=false);
        });
        await audio.setSource(DeviceFileSource(widget.file.path));
      }
      if(mounted)setState(()=>_valid=true);
    }catch(_){
      if(mounted)setState(()=>_valid=false);
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  void _videoChanged(){
    final playing=_video?.value.isPlaying??false;
    if(mounted&&playing!=_playing)setState(()=>_playing=playing);
  }
  Future<void> _toggle() async{
    if(_busy||!_valid||!widget.active)return;
    try{
      if(widget.kind=='video'){
        final controller=_video;
        if(controller==null)return;
        if(controller.value.isPlaying){await controller.pause();}
        else{
          if(controller.value.position>=controller.value.duration)await controller.seekTo(Duration.zero);
          await controller.play();
        }
        return;
      }else{
        final player=_audio;
        if(player==null)return;
        if(_playing)await player.pause();else await player.resume();
      }
      if(mounted)setState(()=>_playing=!_playing);
    }catch(_){
      if(mounted)setState(()=>_playing=false);
    }
  }
  @override
  void didUpdateWidget(covariant OrbitMomentDraftPlayer old){
    super.didUpdateWidget(old);
    if(old.file.path!=widget.file.path || old.kind!=widget.kind){
      unawaited(_reset());
    }else{
      if(old.muted!=widget.muted)unawaited(_video?.setVolume(widget.muted?0:1));
      if(!widget.active&&old.active){unawaited(_video?.pause());unawaited(_audio?.pause());_playing=false;}
    }
  }
  Future<void> _reset() async{
    await _stop();
    if(mounted)setState((){
      _busy=true;_playing=false;_valid=false;
    });
    await _init();
  }
  Future<void> _stop() async {
    await _ended?.cancel();_ended=null;
    final video=_video;_video=null;
    video?.removeListener(_videoChanged);
    try{await video?.pause();await video?.dispose();}catch(_){}
    try{await _audio?.stop();await _audio?.dispose();}catch(_){}
    _video=null;_audio=null;
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed && _playing){
      unawaited(_video?.pause());
      unawaited(_audio?.pause());
      if(mounted)setState(()=>_playing=false);
    }
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    if(_busy)return const Center(child:CircularProgressIndicator(
      color:AppColors.primaryEnd));
    if(!_valid)return Center(child:Text('Unable to play this recording. Try again.',
      textAlign:TextAlign.center,style:AppTypography.bodyMuted));
    if(widget.kind=='video'&&_video?.value.isInitialized==true){
      return LayoutBuilder(builder:(context,limits){
        final size=_video!.value.size;
        final fitted=applyBoxFit(BoxFit.contain,size,limits.biggest).destination;
        return Center(child:SizedBox.fromSize(size:fitted,
          child:Stack(fit:StackFit.expand,children:[
            VideoPlayer(_video!),
            GestureDetector(behavior:HitTestBehavior.opaque,
              onTap:()=>unawaited(_toggle()),
              child:Center(child:Icon(_playing?Icons.pause_circle_filled:Icons.play_circle_fill,
                color:Colors.white.withValues(alpha:_playing?0.65:0.92),size:52))),
          ])));
      });
    }
    return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.graphic_eq_rounded,size:40,color:AppColors.primaryEnd),
      IconButton(onPressed:()=>unawaited(_toggle()),
        tooltip:_playing?'Pause preview':'Play preview',
        icon:Icon(_playing?Icons.pause_circle_filled:Icons.play_circle_fill,
          color:AppColors.primaryEnd,size:40)),
    ]));
  }
}
