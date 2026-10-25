import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/orbit_moment_repository.dart';

/// Playback files are decrypted into the sandbox only after a fresh M7
/// authorization check. No public URI, shared storage or permanent cache.
class OrbitPrivateMomentPlayer extends StatefulWidget {
  const OrbitPrivateMomentPlayer({
    required this.item,required this.repository,this.onFinished,
    this.paused=false,this.previewBytes,super.key,
  });
  final OrbitLiveMoment item;
  final OrbitMomentRepository repository;
  final VoidCallback? onFinished;
  final bool paused;
  final Uint8List? previewBytes;
  @override
  State<OrbitPrivateMomentPlayer> createState()=>_OrbitPrivateMomentPlayerState();
}

class _OrbitPrivateMomentPlayerState extends State<OrbitPrivateMomentPlayer>
    with WidgetsBindingObserver {
  File? _temporary;
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  StreamSubscription<void>? _audioEnd;
  Timer? _videoEndedPoll;
  Timer? _revalidate;
  int _epoch=0;
  bool _busy=true, _playing=false, _muted=false;
  String? _error;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _revalidate=Timer.periodic(const Duration(seconds:15),(_){
      if(mounted && !_busy &&
          WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed){
        unawaited(_check());
      }
    });
  }

  Future<void> _closePlayer() async {
    final video=_video;_video=null;
    final audio=_audio;_audio=null;
    _videoEndedPoll?.cancel();_videoEndedPoll=null;
    final sub=_audioEnd;_audioEnd=null;
    final temp=_temporary;_temporary=null;
    try{await sub?.cancel();}catch(_){}
    try{await video?.pause();await video?.dispose();}catch(_){}
    try{await audio?.stop();await audio?.dispose();}catch(_){}
    await widget.repository.erasePrivateClip(temp);
  }

  Future<void> _check() async {
    final valid=await widget.repository.remainsAuthorized(widget.item);
    if(!mounted || valid)return;
    ++_epoch;
    await _closePlayer();
    if(mounted)setState((){
      _busy=false;
      _playing=false;
      _error='Your access to this Moment has changed.';
    });
  }

  Future<void> _load() async {
    final current=++_epoch;
    if(mounted)setState((){_busy=true;_error=null;_playing=false;});
    try {
      await _closePlayer();
      final file=await widget.repository.openPrivateClip(widget.item);
      if(!mounted || current!=_epoch){
        await widget.repository.erasePrivateClip(file);
        return;
      }
      _temporary=file;
      if(widget.item.mediaKind=='video'){
        final player=VideoPlayerController.file(file);
        _video=player;
        await player.initialize();
        if(!mounted||current!=_epoch)return;
        await player.setLooping(false);
        await player.setVolume(_muted?0:1);
        if(!widget.paused)await player.play();
        _videoEndedPoll=Timer.periodic(const Duration(milliseconds:400),(_){
          if(!mounted || _video!=player || widget.paused)return;
          if(player.value.isInitialized &&
             !player.value.isPlaying &&
             player.value.position>=player.value.duration &&
             player.value.duration>Duration.zero){
            _videoEndedPoll?.cancel();
            widget.onFinished?.call();
          }
        });
      }else{
        final player=AudioPlayer();
        _audio=player;
        _audioEnd=player.onPlayerComplete.listen((_){
          if(mounted){
            setState(()=>_playing=false);
            widget.onFinished?.call();
          }
        });
        await player.setSource(DeviceFileSource(file.path));
        if(!widget.paused)await player.resume();
      }
      if(mounted && current==_epoch)setState((){
        _busy=false;
        _playing=!widget.paused;
      });
    }catch(_){
      await _closePlayer();
      if(mounted && current==_epoch)setState((){
        _busy=false;
        _error='This encrypted clip cannot be played.';
      });
    }
  }

  @override
  void didUpdateWidget(covariant OrbitPrivateMomentPlayer old){
    super.didUpdateWidget(old);
    if(old.paused==widget.paused)return;
    if(widget.paused){
      unawaited(_video?.pause());
      unawaited(_audio?.pause());
      if(mounted)setState(()=>_playing=false);
    }else if(!_busy && _error==null){
      if(_video!=null)unawaited(_video!.play());
      if(_audio!=null)unawaited(_audio!.resume());
      if(mounted)setState(()=>_playing=true);
    }
  }

  Future<void> _toggle() async {
    if(_busy||_error!=null)return;
    try{
      if(widget.item.mediaKind=='video'){
        final player=_video;
        if(player==null)return;
        if(_playing)await player.pause(); else await player.play();
      }else{
        final player=_audio;
        if(player==null)return;
        if(_playing)await player.pause(); else await player.resume();
      }
      if(mounted)setState(()=>_playing=!_playing);
    }catch(_){await _check();}
  }

  Future<void> _toggleMute() async {
    final player=_video;
    if(player==null || _busy || _error!=null)return;
    final next=!_muted;
    try {
      await player.setVolume(next?0:1);
      if(mounted)setState(()=>_muted=next);
    }catch(_){await _check();}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.inactive || state==AppLifecycleState.paused){
      ++_epoch;
      if(mounted)setState((){_busy=true;_playing=false;});
      unawaited(_closePlayer());
    }else if(state==AppLifecycleState.resumed && mounted){
      unawaited(_load());
    }
  }

  @override
  void dispose(){
    ++_epoch;
    _revalidate?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_closePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    if(_busy)return Center(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        if(widget.previewBytes!=null && widget.previewBytes!.isNotEmpty)
          Image.memory(widget.previewBytes!,fit:BoxFit.contain,height:120,
            errorBuilder:(_,error,stack)=>const SizedBox.shrink()),
        const SizedBox(height:12),
        const CircularProgressIndicator(color:AppColors.primaryEnd),
      ]));
    if(_error!=null)return Center(child:Text(_error!,
      textAlign:TextAlign.center,style:AppTypography.bodyMuted));
    final video=_video;
    return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      if(widget.item.mediaKind=='video' && video!=null && video.value.isInitialized)
        AspectRatio(aspectRatio:video.value.aspectRatio,
          child:VideoPlayer(video))
      else if(widget.previewBytes!=null && widget.previewBytes!.isNotEmpty)
        Image.memory(widget.previewBytes!,fit:BoxFit.contain,height:90,
          errorBuilder:(_,error,stack)=>const Icon(
            Icons.graphic_eq_rounded,color:AppColors.primaryEnd,size:64))
      else
        const Icon(Icons.mic_none_outlined,color:AppColors.primaryEnd,size:64),
      const SizedBox(height:16),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(
          icon:Icon(_playing?Icons.pause_circle_filled:Icons.play_circle_fill,
            size:54,color:AppColors.primaryEnd),
          tooltip:_playing?'Pause encrypted clip':'Play encrypted clip',
          onPressed:()=>unawaited(_toggle()),
        ),
        if(widget.item.mediaKind=='video') ...[
          const SizedBox(width:12),
          IconButton(
            icon:Icon(_muted?Icons.volume_off_outlined:Icons.volume_up_outlined,
              size:28,color:AppColors.primaryEnd),
            tooltip:_muted?'Unmute encrypted video':'Mute encrypted video',
            onPressed:()=>unawaited(_toggleMute()),
          ),
        ],
      ]),
    ]));
  }
}
