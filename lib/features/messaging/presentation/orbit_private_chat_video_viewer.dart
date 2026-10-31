import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_circular_icon_button.dart';

/// App-private playback only. Laravel stores ciphertext and never receives
/// a clear video file path or media content key.
class OrbitPrivateChatVideoViewer extends StatefulWidget {
  const OrbitPrivateChatVideoViewer({this.bytes,this.file,super.key})
      :assert(bytes!=null || file!=null);
  final Uint8List? bytes;
  final File? file;
  @override
  State<OrbitPrivateChatVideoViewer> createState() =>
      _OrbitPrivateChatVideoViewerState();
}

class _OrbitPrivateChatVideoViewerState
    extends State<OrbitPrivateChatVideoViewer> {
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
    try {
      final folder=await getTemporaryDirectory();
      await _pruneOrphans(folder);
      final File file;
      if(widget.file!=null){
        file=widget.file!;
        final name=file.uri.pathSegments.last;
        const prefix='orbit_m13_private_video_';
        final validName=name.startsWith(prefix)&&name.endsWith('.mp4')
            && name.length==prefix.length+36+4;
        final transfer=validName
            ?name.substring(prefix.length,name.length-4):'';
        final validTransfer=RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
          r'[0-9a-f]{4}-[0-9a-f]{12}').hasMatch(transfer);
        if(!validName||!validTransfer||
           file.parent.absolute.path!=folder.absolute.path||
           !await file.exists()||
           await file.length()>250*1024*1024){
          throw const FormatException('Invalid private video playback file.');
        }
      }else{
        final bytes=widget.bytes!;
        if(bytes.isEmpty||bytes.length>64*1024*1024){
          throw const FormatException('Encrypted video exceeds safe preview limits.');
        }
        file=File(folder.path+Platform.pathSeparator+
            'orbit_m13_private_video_'+const Uuid().v4()+'.mp4');
        await file.writeAsBytes(bytes,flush:true);
      }
      _source=file;
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
           !(name.endsWith('.mp4') ||
             name.endsWith('.mp4.cipher')))continue;
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
    _source=null;
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
