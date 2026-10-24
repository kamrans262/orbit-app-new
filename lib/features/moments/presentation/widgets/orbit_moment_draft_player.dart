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
    required this.file,required this.kind,required this.muted,super.key,
  });
  final File file;
  final String kind;
  final bool muted;
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
    try{
      if(widget.kind=='video'){
        final video=VideoPlayerController.file(widget.file);
        _video=video;
        await video.initialize();
        await video.setVolume(widget.muted?0:1);
      }else{
        final audio=AudioPlayer();
        _audio=audio;
        _ended=audio.onPlayerComplete.listen((_){
          if(mounted)setState(()=>_playing=false);
        });
        await audio.setSourceDeviceFile(widget.file.path);
      }
      if(mounted)setState(()=>_valid=true);
    }catch(_){
      if(mounted)setState(()=>_valid=false);
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _toggle() async{
    if(_busy||!_valid)return;
    try{
      if(widget.kind=='video'){
        final controller=_video;
        if(controller==null)return;
        if(_playing)await controller.pause();else await controller.play();
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
    }else if(old.muted!=widget.muted){
      unawaited(_video?.setVolume(widget.muted?0:1));
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
    try{await _video?.pause();await _video?.dispose();}catch(_){}
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
    return Center(child:Column(
      mainAxisSize:MainAxisSize.min,
      children:[
        if(widget.kind=='video' && _video?.value.isInitialized==true)
          SizedBox(height:140,
            child:AspectRatio(
              aspectRatio:_video!.value.aspectRatio,
              child:VideoPlayer(_video!)))
        else
          Icon(widget.kind=='video'
            ? Icons.videocam_outlined:Icons.graphic_eq_rounded,
            size:40,color:AppColors.primaryEnd),
        Text(widget.kind=='video'
          ? 'Video ready to encrypt':'Voice ready to encrypt',
          style:AppTypography.body),
        const SizedBox(height:6),
        IconButton(
          onPressed:_valid?()=>unawaited(_toggle()):null,
          tooltip:_playing?'Pause preview':'Play preview',
          icon:Icon(_playing?Icons.pause_circle_filled:Icons.play_circle_fill,
            color:AppColors.primaryEnd,size:40),
        ),
      ],
    ));
  }
}
