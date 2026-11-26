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
    this.paused=false,this.previewBytes,this.onProgress,super.key,
  });
  final OrbitLiveMoment item;
  final OrbitMomentRepository repository;
  final VoidCallback? onFinished;
  final ValueChanged<double>? onProgress;
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
  StreamSubscription<Duration>? _audioPosition;
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
    final pos=_audioPosition;_audioPosition=null;
    try{await pos?.cancel();}catch(_){}
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
          final total=player.value.duration.inMilliseconds;
          if(total>0)widget.onProgress?.call((player.value.position.inMilliseconds/total).clamp(0.0,1.0).toDouble());
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
        _audioPosition=player.onPositionChanged.listen((position){
          final duration=widget.item.durationMs??0;
          if(mounted&&_audio==player&&duration>0)widget.onProgress?.call((position.inMilliseconds/duration).clamp(0.0,1.0).toDouble());
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
    if(_busy)return Center(heightFactor:1,child:FittedBox(fit:BoxFit.scaleDown,
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(widget.previewBytes!=null && widget.previewBytes!.isNotEmpty)
          Image.memory(widget.previewBytes!,fit:BoxFit.contain,height:120,width:240,
            errorBuilder:(_,error,stack)=>const SizedBox.shrink()),
        const SizedBox(height:12),
        const CircularProgressIndicator(color:AppColors.primaryEnd),
      ])));
    if(_error!=null)return Center(heightFactor:1,child:Text(_error!,
      textAlign:TextAlign.center,style:AppTypography.bodyMuted));
    final video=_video;
    final isVideo=widget.item.mediaKind=='video';
    final readyVideo=isVideo && video!=null && video.value.isInitialized?video:null;
    final controls=Row(mainAxisSize:MainAxisSize.min,
      mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(
          icon:Icon(_playing?Icons.pause_circle_filled:Icons.play_circle_fill,
            size:54,color:AppColors.primaryEnd),
          tooltip:_playing?'Pause encrypted clip':'Play encrypted clip',
          onPressed:()=>unawaited(_toggle()),
        ),
        if(isVideo) ...[
          const SizedBox(width:12),
          IconButton(
            icon:Icon(_muted?Icons.volume_off_outlined:Icons.volume_up_outlined,
              size:28,color:AppColors.primaryEnd),
            tooltip:_muted?'Unmute encrypted video':'Mute encrypted video',
            onPressed:()=>unawaited(_toggleMute()),
          ),
        ],
      ]);
    return OrbitMomentClipViewport(
      aspectRatio:readyVideo?.value.aspectRatio,
      controls:controls,
      media:readyVideo!=null?VideoPlayer(readyVideo):
        widget.previewBytes!=null && widget.previewBytes!.isNotEmpty
          ? Image.memory(widget.previewBytes!,fit:BoxFit.contain,height:90,
              errorBuilder:(_,error,stack)=>const Icon(
                Icons.graphic_eq_rounded,color:AppColors.primaryEnd,size:64))
          : const Icon(Icons.mic_none_outlined,color:AppColors.primaryEnd,size:64),
    );
  }
}

/// Reserve space for the existing controls before fitting a video frame.
/// Portrait clips must not consume the controls' vertical space.
class OrbitMomentClipViewport extends StatelessWidget {
  const OrbitMomentClipViewport({required this.media,required this.controls,
    this.aspectRatio,super.key});
  final Widget media,controls;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(context,limits){
    final ratio=aspectRatio;
    if(!limits.hasBoundedHeight||!limits.hasBoundedWidth){
      // A reused player in a scrollable surface still has a finite frame.
      return Column(mainAxisSize:MainAxisSize.min,children:[
        if(ratio!=null&&ratio.isFinite&&ratio>0&&limits.hasBoundedWidth)
          AspectRatio(aspectRatio:ratio,child:media)
        else if(ratio==null)media
        else SizedBox(width:240,height:160,child:media),
        const SizedBox(height:16),controls,
      ]);
    }
    final controlHeight=(limits.maxHeight*0.4).clamp(0.0,70.0).toDouble();
    final gap=(limits.maxHeight*0.08).clamp(0.0,8.0).toDouble();
    final controlRow=SizedBox(height:controlHeight,width:limits.maxWidth,
      child:Center(child:FittedBox(fit:BoxFit.scaleDown,child:controls)));
    if(ratio!=null&&ratio.isFinite&&ratio>0){
      // Fit the frame to the remaining height, then shrink-wrap the
      // combined video and controls instead of inserting a vertical spacer.
      final availableHeight=limits.maxHeight-controlHeight-gap;
      final frameWidth=limits.maxWidth.clamp(0.0,availableHeight*ratio).toDouble();
      final frameHeight=frameWidth/ratio;
      return Column(mainAxisSize:MainAxisSize.min,children:[
        SizedBox(width:frameWidth,height:frameHeight,child:media),
        SizedBox(height:gap),
        controlRow,
      ]);
    }
    // Voice/waveform retains its compact centered layout.
    return Center(heightFactor:1,child:Column(mainAxisSize:MainAxisSize.min,children:[
      Flexible(child:Center(widthFactor:1,heightFactor:1,
        child:FittedBox(fit:BoxFit.scaleDown,child:media))),
      SizedBox(height:gap),controlRow,
    ]));
  });
}
