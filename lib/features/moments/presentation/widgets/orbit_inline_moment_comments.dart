import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_profile_avatar.dart';
import '../../../../core/widgets/app_gradient_action_label.dart';
import '../../data/orbit_moment_repository.dart';
import '../../../realtime/presentation/orbit_realtime_refresh.dart';

typedef _Line=({String id,String author,String body,String? parent});

/// Expands within the existing MomentImageCard, never pushes a route.
class OrbitInlineMomentComments extends StatefulWidget {
  const OrbitInlineMomentComments({required this.moment,required this.repository,
    required this.onClose,required this.onCountChanged,
    this.authorNames=const {},this.authorAvatars=const {},super.key});
  final OrbitLiveMoment moment;
  final OrbitMomentRepository repository;
  final VoidCallback onClose;
  final ValueChanged<int> onCountChanged;
  final Map<String,String> authorNames;
  final Map<String,Uint8List> authorAvatars;
  @override
  State<OrbitInlineMomentComments> createState()=>_OrbitInlineMomentCommentsState();
}
class _OrbitInlineMomentCommentsState extends State<OrbitInlineMomentComments> with WidgetsBindingObserver {
  final _input=TextEditingController();
  final _names=<String,String>{};
  List<_Line> _lines=[];
  OrbitLiveMoment? _scope;
  String? _owner,_error,_parent;
  bool _loading=true,_sending=false,_checking=false;
  int _epoch=0,_limit=30;
  int? _count;
  Timer? _timer;
  OrbitRealtimeRefresh? _refresh;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh=OrbitRealtimeRefresh(modules:const {'moments','social','circles'},
      visible:()=>OrbitRealtimeRefresh.current(this),
      refresh:()=>_load(silent:true),fallback:false)..start();
    _timer=Timer.periodic(const Duration(seconds:25),(_){
      if(mounted&&OrbitRealtimeRefresh.current(this))unawaited(_load(silent:true));
    });
    unawaited(_load());
  }

  Future<void> _load({bool silent=false})async{
    if(_checking||_sending||!mounted)return;
    _checking=true;
    final epoch=++_epoch;
    final item=widget.moment;
    if(!silent)setState((){_loading=true;_error=null;});
    try{
      final owner=await widget.repository.currentUserId();
      if(owner==null)throw StateError('Sign in required');
      final scope=await widget.repository.notificationMoment(item.id,item.interactionContext);
      if(scope.contextId!=item.interactionContext||scope.mediaId!=item.mediaId||
         scope.audienceRevision!=item.audienceRevision)throw StateError('Audience changed');
      final lines=await widget.repository.allComments(scope,max:_limit);
      final names=<String,String>{};
      for(final author in lines.map((line)=>line.author).toSet()){
        if(_names.containsKey(author)){names[author]=_names[author]!;continue;}
        try{names[author]=widget.authorNames[author]??OrbitMomentRepository.firstName(await widget.repository.name(author));}
        catch(_){names[author]='Orbit member';}
      }
      if(!await widget.repository.remainsAuthorized(scope)||
         await widget.repository.currentUserId()!=owner)throw StateError('Audience changed');
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _owner=owner;_scope=scope;_lines=List.of(lines);_names.addAll(names);
        _count=scope.commentCount;_loading=false;_error=null;
      });
      if(_count!=null&&_count!=widget.moment.commentCount)widget.onCountChanged(_count!);
    }catch(_){
      if(mounted&&epoch==_epoch)setState((){
        _scope=null;_owner=null;_lines=[];_names.clear();_input.clear();_parent=null;
        _loading=false;_error='Comments are unavailable. Try again.';
      });
    }finally{
      _checking=false;
      if(mounted&&epoch!=_epoch&&_loading&&WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed){
        unawaited(_load());
      }
    }
  }

  Future<void> _send()async{
    final text=_input.text.trim(),scope=_scope,owner=_owner,parent=_parent;
    if(text.isEmpty||text.length>280||_sending||_checking||scope==null||owner==null)return;
    final epoch=_epoch;
    setState(()=>_sending=true);
    try{
      if(await widget.repository.currentUserId()!=owner||
          !await widget.repository.remainsAuthorized(scope))throw StateError('Audience changed');
      final id=await widget.repository.commentWithReceipt(scope,text,parent:parent);
      if(!await widget.repository.remainsAuthorized(scope)||
          await widget.repository.currentUserId()!=owner)throw StateError('Audience changed');
      if(!mounted||epoch!=_epoch)return;
      setState((){
        if(!_lines.any((line)=>line.id==id)){
          _lines.insert(0,(id:id,author:owner,body:text,parent:parent));
          _count=(_count??_lines.length-1)+1;
        }
        _names[owner]=widget.authorNames[owner]??_names[owner]??'Orbit member';_input.clear();_parent=null;_error=null;
      });
      if(_count!=null)widget.onCountChanged(_count!);
    }catch(_){if(mounted&&epoch==_epoch)setState(()=>_error='Comment could not be sent.');}
    finally{if(mounted&&epoch==_epoch)setState(()=>_sending=false);}
  }

  Future<void> _delete(_Line line)async{
    final scope=_scope,owner=_owner,epoch=_epoch;
    if(scope==null||owner==null||_sending||_checking)return;
    setState(()=>_sending=true);
    try{
      if(await widget.repository.currentUserId()!=owner||
          !await widget.repository.remainsAuthorized(scope))throw StateError('Audience changed');
      await widget.repository.deleteComment(scope,line.id);
      if(!await widget.repository.remainsAuthorized(scope)||
          await widget.repository.currentUserId()!=owner)throw StateError('Audience changed');
      if(!mounted||epoch!=_epoch)return;
      setState((){
        _lines.removeWhere((entry)=>entry.id==line.id);
        _count=((_count??_lines.length+1)-1).clamp(0,1<<31).toInt();
        if(_parent==line.id)_parent=null;
      });
      widget.onCountChanged(_count!);
    }catch(_){if(mounted&&epoch==_epoch)setState(()=>_error='Comment could not be deleted.');}
    finally{if(mounted&&epoch==_epoch)setState(()=>_sending=false);}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.inactive||state==AppLifecycleState.hidden||state==AppLifecycleState.paused){
      ++_epoch;
      if(mounted)setState((){
        _lines=[];_names.clear();_scope=null;_owner=null;_parent=null;_input.clear();
        _loading=true;_sending=false;
      });
    }else if(state==AppLifecycleState.resumed&&mounted){unawaited(_load());}
  }

  @override
  void dispose(){
    ++_epoch;_timer?.cancel();_refresh?.dispose();
    WidgetsBinding.instance.removeObserver(this);_input.dispose();super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Padding(padding:const EdgeInsets.fromLTRB(12,0,12,12),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Divider(height:1,color:AppColors.primaryEnd.withValues(alpha:0.14)),
        Row(children:[
          Expanded(child:Text('Comments',style:AppTypography.smallHeading.copyWith(color:AppColors.primaryEnd))),
          IconButton(tooltip:'Close comments',onPressed:widget.onClose,icon:const Icon(Icons.close_rounded,color:AppColors.primaryEnd)),
        ]),
        if(widget.moment.targetIds.length>1&&widget.moment.interactionContext.startsWith('circle:'))
          Text('Comments in this Circle',style:AppTypography.bodyMuted),
        if(_loading)const Padding(padding:EdgeInsets.all(12),child:Center(child:SizedBox.square(
          dimension:24,child:CircularProgressIndicator(strokeWidth:2,color:AppColors.primaryEnd))))
        else if(_error!=null)Row(children:[
          Expanded(child:Text(_error!,style:AppTypography.bodyMuted)),
          TextButton(onPressed:()=>unawaited(_load()),child:const AppGradientActionLabel('Retry')),
        ]),
        if(!_loading&&_scope!=null&&_lines.isEmpty)
          Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text('No comments yet',style:AppTypography.bodyMuted)),
        for(final line in _lines)Padding(
          padding:EdgeInsets.fromLTRB(line.parent==null?0:14,6,0,6),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            MomentProfileAvatar(author:MomentAuthorData(id:line.author,
              name:_names[line.author]??'Orbit member',imageBytes:widget.authorAvatars[line.author]),
              size:34,borderColor:AppColors.primaryStart.withValues(alpha:0.25),borderWidth:1),
            const SizedBox(width:8),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
                decoration:BoxDecoration(
                  color:AppColors.primaryEnd.withValues(alpha:0.055),
                  borderRadius:BorderRadius.circular(14),
                  border:Border.all(color:AppColors.primaryEnd.withValues(alpha:0.10))),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(_names[line.author]??'Orbit member',style:AppTypography.body.copyWith(
                    fontWeight:FontWeight.w600,color:AppColors.primaryEnd)),
                  const SizedBox(height:3),
                  Text(line.body,style:AppTypography.body.copyWith(color:AppColors.textPrimary)),
                ])),
              Padding(padding:const EdgeInsets.only(left:8,top:4),
                child:Row(children:[
                  InkWell(onTap:()=>setState(()=>_parent=line.id),
                    child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:4),
                      child:Text('Reply',style:AppTypography.bodyMuted.copyWith(
                        color:AppColors.primaryEnd,fontWeight:FontWeight.w600)))),
                  if(line.author==_owner||widget.moment.creatorId==_owner)...[
                    const SizedBox(width:12),
                    InkWell(onTap:()=>unawaited(_delete(line)),
                      child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:4),
                        child:Text('Delete',style:AppTypography.bodyMuted))),
                  ],
                ])),
            ])),
          ])),
        if(_count!=null&&_lines.length<_count!&&_limit<150)
          TextButton(onPressed:(){_limit=(_limit+30).clamp(30,150).toInt();unawaited(_load());},
            child:const AppGradientActionLabel('View more comments')),
        if(_parent!=null)Row(children:[
          Expanded(child:Text('Replying to comment',style:AppTypography.bodyMuted)),
          TextButton(onPressed:()=>setState(()=>_parent=null),child:const AppGradientActionLabel('Cancel')),
        ]),
        if(_scope!=null)Row(children:[
          Expanded(child:TextField(controller:_input,maxLength:280,maxLines:2,minLines:1,
            enabled:!_sending,decoration:InputDecoration(hintText:'Write a comment',counterText:'',
              filled:true,fillColor:AppColors.primaryEnd.withValues(alpha:0.045),
              contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
              enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(24),
                borderSide:BorderSide(color:AppColors.primaryEnd.withValues(alpha:0.16))),
              focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(24),
                borderSide:const BorderSide(color:AppColors.primaryEnd))))),
          const SizedBox(width:8),
          Semantics(button:true,label:'Send comment',child:Material(color:Colors.transparent,
            child:Ink(decoration:const BoxDecoration(shape:BoxShape.circle,gradient:AppColors.primaryGradient),
              child:InkWell(customBorder:const CircleBorder(),onTap:()=>unawaited(_send()),
                child:const SizedBox.square(dimension:40,child:Icon(Icons.send_rounded,color:AppColors.white,size:20)))))),
        ]),
      ]));
  }
}
