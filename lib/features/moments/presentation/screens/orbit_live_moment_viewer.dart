import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../data/orbit_moment_repository.dart';

/// Private viewer reuses the existing Orbit detail scaffold, action icons and
/// approved modal-sheet shapes. No share/public URL, preview mock, or new theme.
class OrbitLiveMomentViewer extends StatefulWidget {
  const OrbitLiveMomentViewer({required this.moment,required this.repository,
    required this.author,this.playlist=const [],this.initialIndex=0,
    this.authorNames=const {},super.key});
  final OrbitLiveMoment moment;
  final OrbitMomentRepository repository;
  final String author;
  final List<OrbitLiveMoment> playlist;
  final int initialIndex;
  final Map<String,String> authorNames;
  @override
  State<OrbitLiveMomentViewer> createState()=>_OrbitLiveMomentViewerState();
}

class _OrbitLiveMomentViewerState extends State<OrbitLiveMomentViewer> {
  Uint8List? _photo;
  String? _caption;
  String? _error;
  bool _loading=true, _liked=false, _sending=false, _paused=false;
  Timer? _advance;
  late int _index;
  OrbitLiveMoment get _current => widget.playlist.isEmpty
      ? widget.moment : widget.playlist[_index];
  String get _name => widget.authorNames[_current.creatorId]??widget.author;
  @override
  void initState(){
    super.initState();
    _index=widget.playlist.isEmpty?0:widget.initialIndex.clamp(0,widget.playlist.length-1);
    unawaited(_load());
  }
  @override
  void dispose(){
    _advance?.cancel();
    _photo=null;
    super.dispose();
  }
  void _schedule(){
    _advance?.cancel();
    if(widget.playlist.isEmpty||_paused||_loading||_error!=null)return;
    _advance=Timer(const Duration(seconds:5),()=>_move(1));
  }
  void _move(int amount){
    if(!mounted || widget.playlist.isEmpty)return;
    final to=_index+amount;
    if(to<0)return;
    if(to>=widget.playlist.length){
      Navigator.of(context).maybePop();
      return;
    }
    _advance?.cancel();
    setState(() {
      _index=to;_photo=null;_caption=null;_loading=true;_liked=false;
      _error=null;
    });
    unawaited(_load());
  }
  void _pause(bool value){
    _paused=value;
    if(value)_advance?.cancel();else _schedule();
  }
  void _navigationTap(TapUpDetails tap,BoxConstraints constraints){
    if(widget.playlist.isEmpty)return;
    _move(tap.localPosition.dx<constraints.maxWidth/2?-1:1);
  }
  Future<void> _load() async {
    try{
      final current=_current;
      final photo=await widget.repository.photo(current,variant:'original');
      final caption=await widget.repository.caption(current);
      await widget.repository.view(current);
      if(mounted && _current.id==current.id){
        setState((){_photo=photo;_caption=caption;_loading=false;});
        _schedule();
      }
    }catch(_){
      if(mounted)setState((){
        _error='This encrypted Moment is unavailable or access has changed.';
        _loading=false;
      });
    }
  }
  Future<void> _toggleLike() async {
    if(_sending)return;
    final liked=!_liked;setState(()=>_sending=true);
    try {
      await widget.repository.react(_current,liked:liked);
      if(mounted)setState(()=>_liked=liked);
    }catch(_){if(mounted)_notice('The reaction could not be saved.');}
    finally{if(mounted)setState(()=>_sending=false);}
  }
  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }
  Future<void> _commentSheet() async {
    final controller=TextEditingController();
    var lines=<({String id,String author,String body,String? parent})>[];
    String? error;
    try {lines=await widget.repository.allComments(_current);}
    catch(_){error='Comments are unavailable. Please try again.';}
    if(!mounted){controller.dispose();return;}
    String? replyingTo;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,useSafeArea:true,
      backgroundColor:AppColors.background,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
      builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,setSheet)=>Padding(
        padding:EdgeInsets.fromLTRB(20,16,20,
          MediaQuery.viewInsetsOf(sheetContext).bottom+20),
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Moment comments',style:AppTypography.smallHeading),
            const SizedBox(height:12),
            if(error!=null)Text(error,style:AppTypography.bodyMuted),
            SizedBox(height:180,child:ListView.builder(
              itemCount:lines.length,itemBuilder:(_,index)=>Padding(
                padding:const EdgeInsets.only(bottom:12),
                child:ListTile(
                  title:Text(lines[index].body,style:AppTypography.body),
                  subtitle:Text(lines[index].parent==null
                      ? 'Reply':'Reply in thread',style:AppTypography.bodyMuted),
                  onTap:()=>setSheet(()=>replyingTo=lines[index].id),
                )))),
            if(replyingTo!=null)Row(children:[
              Expanded(child:Text('Replying to comment',
                style:AppTypography.bodyMuted)),
              TextButton(onPressed:()=>setSheet(()=>replyingTo=null),
                child:const Text('Cancel reply')),
            ]),
            TextField(controller:controller,maxLength:280,maxLines:2,
              decoration:const InputDecoration(hintText:'Write a comment')),
            const SizedBox(height:10),
            AppPrimaryButton(label:'Send comment',onPressed:() async {
              final text=controller.text.trim();
              if(text.isEmpty)return;
              try{
                await widget.repository.comment(_current,text,parent:replyingTo);
                if(sheetContext.mounted)Navigator.of(sheetContext).pop();
              }catch(_){
                if(mounted)_notice('Comment could not be sent.');
              }
            }),
          ],
        ),
      )),
    );
    controller.dispose();
  }
  Future<void> _reportSheet() async {
    const reasons=<String,String>{
      'spam':'Spam','harassment':'Harassment','threat':'Threats',
      'scam':'Scam','impersonation':'Impersonation',
      'nudity':'Nudity','violence':'Violence','privacy':'Privacy',
      'safety_concern':'Safety concern','other':'Other',
    };
    final code=await showModalBottomSheet<String>(
      context:context,useSafeArea:true,isScrollControlled:true,
      backgroundColor:AppColors.background,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
      builder:(sheet)=>SafeArea(child:Padding(
        padding:const EdgeInsets.fromLTRB(20,16,20,20),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text('Report Moment',style:AppTypography.smallHeading),
          const SizedBox(height:10),
          ...reasons.entries.map((entry)=>ListTile(
            title:Text(entry.value,style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop(entry.key),
          )),
        ]),
      )),
    );
    if(code==null)return;
    try{
      await widget.repository.report(_current,code);
      if(mounted)_notice('Your report has been submitted.');
    }catch(_){if(mounted)_notice('Unable to submit this report.');}
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor:AppColors.background,
      body:SafeArea(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:20),
        child:Column(children:[
          const SizedBox(height:20),
          AppScreenHeader(title:_name,prominent:true),
          const SizedBox(height:20),
          Expanded(child:LayoutBuilder(builder:(context,limits)=>
            GestureDetector(
              behavior:HitTestBehavior.opaque,
              onTapUp:(event)=>_navigationTap(event,limits),
              onLongPressStart:(_)=>_pause(true),
              onLongPressEnd:(_)=>_pause(false),
              onVerticalDragEnd:(details){
                final speed=details.primaryVelocity??0;
                if(speed>350)Navigator.of(context).maybePop();
              },
              child:Center(child:_loading
                ? const CircularProgressIndicator(color:AppColors.primaryEnd)
                : _error!=null
                  ? Text(_error!,textAlign:TextAlign.center,style:AppTypography.bodyMuted)
                  : ClipRRect(borderRadius:BorderRadius.circular(16),
                    child:Image.memory(_photo!,fit:BoxFit.contain))),
            ))),
          if(_caption!=null&&_caption!.isNotEmpty)
            Padding(padding:const EdgeInsets.symmetric(vertical:12),
              child:Text(_caption!,style:AppTypography.body)),
          if(_error==null&&!_loading)
            Row(children:[
              AppCircularIconButton(
                semanticLabel:_liked?'Unlike moment':'Like moment',
                onPressed:_toggleLike,
                icon:_liked?Icons.favorite_rounded:Icons.favorite_border_rounded,
                iconSize:20,size:40),
              const SizedBox(width:12),
              AppCircularIconButton(
                semanticLabel:'Comments',onPressed:()=>unawaited(_commentSheet()),
                icon:Icons.chat_bubble_outline_rounded,
                iconSize:20,size:40),
              const Spacer(),
              AppCircularIconButton(
                semanticLabel:'Report Moment',
                onPressed:()=>unawaited(_reportSheet()),
                icon:Icons.flag_outlined,iconSize:20,size:40),
            ]),
          const SizedBox(height:22),
        ]),
      )),
    );
  }
}
