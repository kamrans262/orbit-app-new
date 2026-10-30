import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_circular_icon_button.dart';

/// Temporary app-private playback only. Laravel still receives ciphertext.
/// The video plugin needs a file path; decrypted bytes are written only to
/// the platform's non-public temporary area and deleted on close/failure.
/// Device storage security remains an independent release-review topic.
class OrbitPrivateChatVideoViewer extends StatefulWidget {
  const OrbitPrivateChatVideoViewer({required this.bytes,super.key});
  final Uint8List bytes;
  @override
  State<OrbitPrivateChatVideoViewer> createState()=>_OrbitPrivateChatVideoViewerState();
}
class _OrbitPrivateChatVideoViewerState extends State<OrbitPrivateChatVideoViewer> {
  File? _source;
  VideoPlayerController? _player;
  bool _working=true;
  String? _error;

  @override
  void initState(){
    super.initState();
    unawaited(_initialize());
  }
  Future<void> _initialize() async {
    try{
      if(widget.bytes.isEmpty||widget.bytes.length>64*1024*1024){
        throw const FormatException('Encrypted video exceeds safe preview limits.');
      }
      final folder=await getTemporaryDirectory();
      // A previous process may have been killed during playback. Clean up
      // stale app-private decrypted previews, never user-selected originals.
      await _pruneOrphans(folder);
      if(!mounted)return;
      final file=File(folder.path+Platform.pathSeparator+
        'orbit_m13_private_video_'+const Uuid().v4()+'.mp4');
      _source=file;
      await file.writeAsBytes(widget.bytes,flush:true);
      if(!mounted){await _cleanup();return;}
      final player=VideoPlayerController.file(file);
      _player=player;
      await player.initialize();
      if(!mounted){await _cleanup();return;}
      setState(()=>_working=false);
      await player.play();
    }catch(_){
      if(mounted)setState((){
        _working=false;
        _error='This encrypted video could not be played.';
      });
      await _cleanup();
    }
  }
  Future<void> _pruneOrphans(Directory folder) async {
    try{
      await for(final entity in folder.list(followLinks:false)){
        if(entity is! File)continue;
        final name=entity.uri.pathSegments.last;
        if(!name.startsWith('orbit_m13_private_video_')||
           !name.endsWith('.mp4'))continue;
        final changed=await entity.lastModified();
        if(DateTime.now().difference(changed)>const Duration(hours:1)){
          try{await entity.delete();}catch(_){}
        }
      }
    }catch(_){}
  }

  Future<void> _cleanup() async {
    try{await _player?.dispose();}catch(_){}
    try{
      final file=_source;
      if(file!=null&&await file.exists())await file.delete();
    }catch(_){}
  }
  @override
  void dispose(){
    unawaited(_cleanup());
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Colors.black,
    body:SafeArea(child:Stack(children:[
      Center(child:_working
        ?const CircularProgressIndicator(color:Color(0xFF7C5CFC))
        :_error!=null
          ?Text(_error!,textAlign:TextAlign.center,
            style:const TextStyle(fontFamily:AppTypography.fontFamily,
              color:Colors.white))
          :AspectRatio(
            aspectRatio:_player!.value.aspectRatio,
            child:VideoPlayer(_player!))),
      Positioned(top:10,left:12,child:AppCircularIconButton(
        semanticLabel:'Back',icon:Icons.chevron_left_rounded,
        onPressed:()=>Navigator.of(context).maybePop())),
      if(!_working&&_error==null)Positioned(
        bottom:18,left:0,right:0,
        child:Center(child:IconButton(
          color:Colors.white,iconSize:36,
          icon:Icon(_player?.value.isPlaying==true
            ?Icons.pause_circle_outline_rounded
            :Icons.play_circle_outline_rounded),
          onPressed:() async{
            final player=_player;
            if(player==null)return;
            if(player.value.isPlaying)await player.pause();
            else await player.play();
            if(mounted)setState((){});
          }))),
    ])),
  );
}
