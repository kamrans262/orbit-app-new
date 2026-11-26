import '../../../realtime/data/orbit_realtime_contract.dart';
import '../../../realtime/presentation/orbit_realtime_refresh.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/navigation/orbit_moment_link.dart';
import 'package:orbit_ui/core/widgets/app_gradient_action_label.dart';
import 'package:image/image.dart' as img;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../data/orbit_moment_repository.dart';
import '../widgets/orbit_private_moment_player.dart';

/// Private viewer reuses the existing Orbit detail scaffold, action icons and
/// approved detail components. Shared HTTPS references never grant media access.
class OrbitLiveMomentViewer extends StatefulWidget {
  const OrbitLiveMomentViewer({required this.moment,required this.repository,
    required this.author,this.playlist=const [],this.initialIndex=0,
    this.authorNames=const {},this.openComments=false,this.onViewed,super.key});
  final OrbitLiveMoment moment;
  final OrbitMomentRepository repository;
  final String author;
  final List<OrbitLiveMoment> playlist;
  final int initialIndex;
  final Map<String,String> authorNames;
  final bool openComments;
  final ValueChanged<String>? onViewed;
  @override
  State<OrbitLiveMomentViewer> createState()=>_OrbitLiveMomentViewerState();
}

class _OrbitLiveMomentViewerState extends State<OrbitLiveMomentViewer> with WidgetsBindingObserver,SingleTickerProviderStateMixin {
  Uint8List? _photo;
  String? _caption;
  int? _ownerPublishVersion,_ownerAudienceRevision;
  String _ownerAudienceKind='only_me';
  Set<String> _ownerTargets=<String>{};
  Set<String> _ownerTags=<String>{};
  String? _error;
  bool _loading=true, _liked=false, _sending=false, _paused=false;
  bool _allCaughtUp=false;
  bool _isOwner=false;
  bool _reauthorizing=false;
  Timer? _advance;
  late final AnimationController _progress;
  final ValueNotifier<double> _clipProgress=ValueNotifier(0);
  bool _commentsOpen=false,_commentsLoading=false,_commentSending=false;
  final _commentInput=TextEditingController();
  List<({String id,String author,String body,String? parent})> _comments=[];
  final Map<String,String> _commentNames={};
  String? _commentError,_replyingTo;
  String? _commentViewer;
  OrbitLiveMoment? _commentMoment;
  String? _commentContext;
  bool _openedInitialComments=false;
  int _commentEpoch=0;
  Timer? _revalidation;
  int _loadEpoch=0;
  late int _index;
  OrbitLiveMoment get _current => widget.playlist.isEmpty
      ? widget.moment : widget.playlist[_index];
  String get _name => widget.authorNames[_current.creatorId]??widget.author;
  OrbitRealtimeRefresh? _m25Refresh;
  @override
  void initState(){
    super.initState();
    _progress=AnimationController(vsync:this,duration:const Duration(seconds:5))
      ..addStatusListener((status){
        if(status==AnimationStatus.completed&&mounted&&!_paused&&!_loading&&_error==null){
          _move(1);
        }
      });
    _m25Refresh=OrbitRealtimeRefresh(modules:const {'moments','circles','social'},visible:()=>OrbitRealtimeRefresh.current(this),refresh:()=>_checkAuthorization(),fallback:false)..start();

    WidgetsBinding.instance.addObserver(this);
    _index=widget.playlist.isEmpty?0:widget.initialIndex.clamp(0,widget.playlist.length-1);
    _revalidation=Timer.periodic(const Duration(seconds:20),(_){
      if(!mounted || _loading || _error!=null ||
          (WidgetsBinding.instance.lifecycleState==AppLifecycleState.paused ||
           WidgetsBinding.instance.lifecycleState==AppLifecycleState.inactive ||
           WidgetsBinding.instance.lifecycleState==AppLifecycleState.hidden) ||
          ModalRoute.of(context)?.isCurrent!=true)return;
      if(OrbitRealtimeRollout.selected){_m25Refresh?.poll();}else{
      unawaited(_checkAuthorization());
      }
    });
    unawaited(_load());
  }

  void _forgetPhoto(){
    final bytes=_photo;
    if(bytes!=null)unawaited(MemoryImage(bytes).evict());
    _photo=null;
    _caption=null;
    _resetComments();
  }
  Future<void> _checkAuthorization() async {
    if(!mounted || _loading || _reauthorizing || _allCaughtUp)return;
    _reauthorizing=true;
    final moment=_current;
    final epoch=_loadEpoch;
    // Keep the existing native player mounted during a successful
    // authorization refresh. Recreating it every 20 seconds would restart
    // long video/audio playback and lose the viewer's progress.
    final valid=await widget.repository.remainsAuthorized(moment);
    _reauthorizing=false;
    if(!mounted || epoch!=_loadEpoch || _current.id!=moment.id)return;
    if(valid&&_commentsOpen&&_commentMoment!=null){
      final scoped=_commentMoment!;
      if(!await widget.repository.remainsAuthorized(scoped)){
        if(mounted&&epoch==_loadEpoch&&identical(_commentMoment,scoped))setState(_resetComments);
      }
      return;
    }
    if(!valid){
      _advance?.cancel();_progress.stop();
      setState((){
        ++_loadEpoch;
        _forgetPhoto();
        _loading=false;
        _error='This encrypted Moment is unavailable or access has changed.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.inactive || state==AppLifecycleState.paused){
      _advance?.cancel();_progress.stop();
      ++_loadEpoch;
      if(mounted)setState((){
        _forgetPhoto();
        _loading=true;
        _error=null;
      });
    }else if(state==AppLifecycleState.resumed && mounted){
      unawaited(_load());
    }
  }

  @override
  void dispose(){
    _m25Refresh?.dispose();

    ++_loadEpoch;
    _advance?.cancel();
    _progress.dispose();
    _clipProgress.dispose();
    _revalidation?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _forgetPhoto();
    _commentInput.dispose();
    super.dispose();
  }
  void _schedule(){
    _advance?.cancel();
    if(widget.playlist.isEmpty||_paused||_loading||_error!=null ||
        _allCaughtUp ||
        (MediaQuery.maybeOf(context)?.disableAnimations??false))return;
    if(_current.mediaKind=='image')_progress.forward();
  }
  void _move(int amount){
    if(!mounted || widget.playlist.isEmpty||_commentsOpen)return;
    final to=_index+amount;
    if(to<0)return;
    if(to>=widget.playlist.length){
      _advance?.cancel();_progress.stop();
      setState((){
        _forgetPhoto();
        _allCaughtUp=true;
      });
      return;
    }
    _advance?.cancel();
    _progress.reset();_clipProgress.value=0;_paused=false;
    setState(() {
      _forgetPhoto();
      _index=to;_loading=true;_liked=false;
      _allCaughtUp=false;
      _error=null;
    });
    unawaited(_load());
  }
  void _pause(bool value){
    _paused=value;
    if(mounted)setState((){});
    if(value){_advance?.cancel();_progress.stop();}else _schedule();
  }
  void _navigationTap(TapUpDetails tap,BoxConstraints constraints){
    if(widget.playlist.isEmpty||_commentsOpen)return;
    _move(tap.localPosition.dx<constraints.maxWidth/2?-1:1);
  }
  Future<void> _load() async {
    final epoch=++_loadEpoch;
    if(!mounted)return;
    setState((){
      _advance?.cancel();
      _progress.reset();_clipProgress.value=0;
      _forgetPhoto();
      _loading=true;
      _error=null;
    });
    try{
      final current=_current;
      // A stale story response cannot retain access if the policy changed.
      if(!await widget.repository.remainsAuthorized(current)){
        throw StateError('Audience authorization expired');
      }
      // First display a separately authorized thumbnail; request the
      // original only after another live permission check.
      final photo=current.mediaKind=='image' || current.mediaKind=='audio'
        ? await widget.repository.photo(current,variant:'thumbnail')
        : Uint8List(0);
      final caption=await widget.repository.caption(current);
      await widget.repository.view(current);
      String? viewer;
      try { viewer=await widget.repository.currentUserId(); } catch (_) {}
      if(mounted && epoch==_loadEpoch && _current.id==current.id){
        setState((){
          _photo=photo;
          _caption=caption;
          _liked=current.myReaction=='like';
          _ownerPublishVersion=current.publishVersion;
          _ownerAudienceRevision=current.audienceRevision;
          _ownerAudienceKind=current.audienceKind;
          _ownerTargets=current.targetIds.toSet();
          _ownerTags=current.taggedUserIds.toSet();
          _isOwner=viewer!=null && viewer==current.creatorId;
          _loading=false;
        });
        widget.onViewed?.call(current.id);
        if(widget.openComments&&!_openedInitialComments){
          _openedInitialComments=true;unawaited(_commentSheet());
        }else{_paused=false;_schedule();}
        if(current.mediaKind=='image'){
          unawaited(_upgradeOriginal(current,epoch));
        }
      }else{
        unawaited(MemoryImage(photo).evict());
      }
    }catch(_){
      if(mounted && epoch==_loadEpoch)setState((){
        _forgetPhoto();
        _error='This encrypted Moment is unavailable or access has changed.';
        _loading=false;
      });
    }
  }
  Future<void> _upgradeOriginal(OrbitLiveMoment current,int epoch) async {
    Uint8List? original;
    try {
      if(!await widget.repository.remainsAuthorized(current))return;
      original=await widget.repository.photo(current,variant:'original');
      if(!await widget.repository.remainsAuthorized(current))return;
      if(!mounted || epoch!=_loadEpoch || _loading ||
         _error!=null || _current.id!=current.id)return;
      final thumbnail=_photo;
      setState(()=>_photo=original);
      original=null; // The active widget now owns these decrypted bytes.
      if(thumbnail!=null)unawaited(MemoryImage(thumbnail).evict());
    }catch(_){
      // A failed download never reveals a public original or hides the
      // thumbnail that was previously authorized.
    }finally{
      if(original!=null)unawaited(MemoryImage(original).evict());
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
  void _resetComments(){
    ++_commentEpoch;
    _commentsOpen=false;_commentsLoading=false;_commentSending=false;
    _comments=[];_commentNames.clear();_commentError=null;_replyingTo=null;
    _commentViewer=null;_commentMoment=null;_commentContext=null;_commentInput.clear();
  }

  Future<void> _commentSheet() async {
    if(!mounted||_loading||_error!=null||_allCaughtUp)return;
    if(_commentsOpen){
      setState(_resetComments);_pause(false);return;
    }
    _pause(true);
    setState(()=>_commentsOpen=true);
    await _loadComments();
  }

  List<String> get _commentContexts=>!_isOwner?[_current.contextId]:[
    if(_ownerAudienceKind=='accepted_friends'||_ownerAudienceKind=='selected_friends')'friends',
    if(_ownerAudienceKind=='selected_circles')..._ownerTargets.map((id)=>'circle:$id'),
    'self',
  ];
  String _contextLabel(String value){
    if(value=='friends')return 'Friends';
    if(value=='self')return 'Only Me';
    return 'Circle ${'${_commentContexts.indexOf(value)+1}'}';
  }

  Future<void> _loadComments({String? contextId}) async{
    final current=_current;
    final scope=contextId??_commentContext??_commentContexts.first;
    final epoch=++_commentEpoch;
    setState((){_commentsLoading=true;_commentError=null;
      _comments=[];_commentNames.clear();_replyingTo=null;_commentContext=scope;
      _commentMoment=null;_commentViewer=null;});
    try{
      final item=scope==current.contextId?current:
        await widget.repository.notificationMoment(current.id,scope);
      final viewer=await widget.repository.currentUserId();
      if(viewer==null||!await widget.repository.remainsAuthorized(item))throw StateError('Not authorized');
      final lines=await widget.repository.allComments(item);
      final names=<String,String>{};
      for(final author in lines.map((e)=>e.author).toSet().take(30)){
        try{names[author]=author==viewer?'You':await widget.repository.name(author);}
        catch(_){names[author]='Orbit member';}
      }
      if(!mounted||epoch!=_commentEpoch||!_commentsOpen||_current.id!=item.id)return;
      if(!await widget.repository.remainsAuthorized(item)||await widget.repository.currentUserId()!=viewer)throw StateError('Not authorized');
      if(!mounted||epoch!=_commentEpoch||!_commentsOpen)return;
      setState((){
        _comments=List.of(lines);_commentNames.addAll(names);_commentViewer=viewer;_commentMoment=item;
        _commentsLoading=false;
      });
    }catch(_){
      if(mounted&&epoch==_commentEpoch&&_commentsOpen)setState((){
        _comments=[];_commentNames.clear();_commentsLoading=false;
        _commentError='Comments are unavailable. Please try again.';
      });
    }
  }

  Future<void> _sendComment() async{
    final text=_commentInput.text.trim();
    if(text.isEmpty||text.length>280||_commentSending||_commentsLoading||_commentViewer==null||_commentMoment==null)return;
    final item=_commentMoment!,epoch=_commentEpoch,viewer=_commentViewer!,parent=_replyingTo;
    setState(()=>_commentSending=true);
    try{
      if(await widget.repository.currentUserId()!=viewer||!await widget.repository.remainsAuthorized(item))throw StateError('Not authorized');
      final id=await widget.repository.commentWithReceipt(item,text,parent:parent);
      if(!mounted||epoch!=_commentEpoch||!_commentsOpen||_current.id!=item.id)return;
      if(!await widget.repository.remainsAuthorized(item)||await widget.repository.currentUserId()!=viewer)throw StateError('Not authorized');
      if(!mounted||epoch!=_commentEpoch||!_commentsOpen)return;
      setState((){
        if(!_comments.any((c)=>c.id==id))_comments.insert(0,(id:id,author:viewer,body:text,parent:parent));
        _commentNames[viewer]='You';_commentInput.clear();_replyingTo=null;_commentError=null;
      });
    }catch(_){
      if(mounted&&epoch==_commentEpoch)setState(()=>_commentError='Comment could not be sent.');
    }finally{
      if(mounted&&epoch==_commentEpoch)setState(()=>_commentSending=false);
    }
  }

  Widget _commentsPanel(){
    final item=_commentMoment??_current;
    return Material(
      color:AppColors.background,borderRadius:BorderRadius.circular(16),
      child:Padding(padding:const EdgeInsets.symmetric(vertical:8),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
            Expanded(child:Text('Moment comments',style:AppTypography.smallHeading)),
            IconButton(tooltip:'Close comments',onPressed:()=>unawaited(_commentSheet()),icon:const Icon(Icons.close_rounded)),
          ]),
          if(_isOwner&&_commentContexts.length>1)DropdownButton<String>(
            value:_commentContext??_commentContexts.first,
            isExpanded:true,
            items:[for(final scope in _commentContexts)DropdownMenuItem(value:scope,child:Text(_contextLabel(scope),style:AppTypography.body))],
            onChanged:_commentSending?null:(scope){if(scope!=null)unawaited(_loadComments(contextId:scope));}),
          if(_commentError!=null)Row(children:[
            Expanded(child:Text(_commentError!,style:AppTypography.bodyMuted)),
            TextButton(onPressed:_commentSending?null:()=>unawaited(_loadComments()),child:const AppGradientActionLabel('Retry')),
          ]),
          SizedBox(height:140,child:_commentsLoading
            ? const Center(child:CircularProgressIndicator(color:AppColors.primaryEnd))
            : _comments.isEmpty?Center(child:Text('No comments yet',style:AppTypography.bodyMuted))
            :ListView.builder(itemCount:_comments.length,itemBuilder:(_,index){
              final line=_comments[index];
              return ListTile(
                dense:true,title:Text(line.body,style:AppTypography.body),
                subtitle:Text((_commentNames[line.author]??'Orbit member')+
                  (line.parent==null?'':' · Reply'),style:AppTypography.bodyMuted),
                onTap:()=>setState(()=>_replyingTo=line.id),
                trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                  if(line.author==_commentViewer||item.creatorId==_commentViewer)IconButton(
                    tooltip:'Delete comment',icon:const Icon(Icons.delete_outline_rounded),
                    onPressed:()async{
                      final epoch=_commentEpoch;
                      try{
                        await widget.repository.deleteComment(item,line.id);
                        if(mounted&&epoch==_commentEpoch)setState((){
                          _comments.removeWhere((c)=>c.id==line.id);
                          if(_replyingTo==line.id)_replyingTo=null;
                        });
                      }catch(_){if(mounted)_notice('Comment could not be deleted.');}
                    }),
                  IconButton(tooltip:'Report this private comment',icon:const Icon(Icons.flag_outlined),
                    onPressed:()=>unawaited(_reportSheet(commentId:line.id,commentMoment:item))),
                ]),
              );
            })),
          if(_replyingTo!=null)Row(children:[
            Expanded(child:Text('Replying to comment',style:AppTypography.bodyMuted)),
            TextButton(onPressed:()=>setState(()=>_replyingTo=null),child:const AppGradientActionLabel('Cancel reply')),
          ]),
          Row(children:[
            Expanded(child:TextField(controller:_commentInput,maxLength:280,maxLines:1,
              enabled:!_commentSending,decoration:const InputDecoration(hintText:'Write a comment',counterText:''))),
            AppCircularIconButton(semanticLabel:'Send comment',onPressed:()=>unawaited(_sendComment()),
              icon:Icons.send_rounded,iconSize:20,size:40),
          ]),
        ])),
    );
  }

  Future<void> _share() async{
    final item=_current;
    final wasPaused=_paused;
    _pause(true);
    try{
      if(!await widget.repository.remainsAuthorized(item))throw StateError('Not authorized');
      await Share.share(OrbitMomentLink.create(item.id).toString());
    }catch(_){if(mounted)_notice('This Moment is no longer shareable.');}
    finally{if(mounted)_pause(wasPaused);}
  }

  Widget _storyProgress(){
    final group=widget.playlist.where((m)=>m.creatorId==_current.creatorId&&m.contextId==_current.contextId).toList();
    return AnimatedBuilder(animation:Listenable.merge([_progress,_clipProgress]),builder:(_,__)=>Row(children:[
      for(final m in group)Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),
        child:ClipRRect(borderRadius:BorderRadius.circular(3),
          child:LinearProgressIndicator(minHeight:3,
            value:m.id==_current.id?(_current.mediaKind=='image'?_progress.value:_clipProgress.value):
              widget.playlist.indexOf(m)<_index?1:0,
            color:AppColors.primaryEnd,backgroundColor:AppColors.primaryEnd.withValues(alpha:0.18))))),
    ]));
  }
  Future<void> _reportSheet({String? commentId,bool account=false,OrbitLiveMoment? commentMoment}) async {
    final reportMoment=commentMoment??_current;
    final wasPaused=_paused;_pause(true);
    try{await _reportSheetBody(reportMoment:reportMoment,commentId:commentId,account:account);}
    finally{if(mounted)_pause(wasPaused);}
  }
  Future<void> _reportSheetBody({required OrbitLiveMoment reportMoment,String? commentId,bool account=false}) async {
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
          Text(account?'Report account':
            commentId!=null?'Report comment':'Report Moment',
            style:AppTypography.smallHeading),
          const SizedBox(height:10),
          ...reasons.entries.map((entry)=>ListTile(
            title:Text(entry.value,style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop(entry.key),
          )),
        ]),
      )),
    );
    if(code==null)return;
    bool includePreview=false;
    try {
      final allowed=await widget.repository.volunteerEvidenceAllowed();
      if(allowed && mounted){
        final result=await showModalBottomSheet<bool>(
          context:context,useSafeArea:true,
          backgroundColor:AppColors.background,
          shape:const RoundedRectangleBorder(
            borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
          builder:(sheet)=>StatefulBuilder(builder:(sheet,update)=>
            Padding(padding:const EdgeInsets.all(20),
              child:Column(mainAxisSize:MainAxisSize.min,
                crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text('Report evidence',style:AppTypography.smallHeading),
                const SizedBox(height:12),
                Text('Your report can be sent without a preview. Sharing a preview is optional and lets an approved moderator see only this volunteered image.',
                  style:AppTypography.bodyMuted),
                const SizedBox(height:12),
                CheckboxListTile(
                  value:includePreview,
                  title:Text('I consent to share this preview with moderators',
                    style:AppTypography.body),
                  onChanged:(value)=>update(()=>includePreview=value==true)),
                const SizedBox(height:12),
                AppPrimaryButton(label:'Send report',
                  onPressed:()=>Navigator.of(sheet).pop(includePreview)),
              ])),
          ),
        );
        if(result==null)return;
        includePreview=result;
      }
    }catch(_){includePreview=false;}
    Uint8List? evidence;
    if(includePreview){
      try{
        final source=img.decodeImage(await widget.repository.photo(_current));
        if(source==null)throw const FormatException('No safe preview.');
        var clean=img.copyResize(source,
          width:source.width>320?320:source.width);
        final reencoded=img.Image(width:clean.width,height:clean.height,
          numChannels:3);
        img.compositeImage(reencoded,clean);
        var jpeg=img.encodeJpg(reencoded,quality:55);
        if(jpeg.length>40960){
          clean=img.copyResize(reencoded,width:160);
          jpeg=img.encodeJpg(clean,quality:50);
        }
        if(jpeg.length>40960)throw const FormatException('Preview too large.');
        evidence=Uint8List.fromList(jpeg);
      }catch(_){
        includePreview=false;
        if(mounted)_notice('Preview unavailable. Report will be sent without it.');
      }
    }
    try{
      await widget.repository.report(reportMoment,code,
        commentId:commentId,account:account,
        volunteeredPreview:includePreview?evidence:null);
      if(mounted)_notice('Your report has been submitted.');
    }catch(_){if(mounted)_notice('Unable to submit this report.');}
  }
  Future<void> _ownerEditCaption() async {
    if(!_isOwner || !mounted)return;
    final item=_current;
    final controller=TextEditingController(text:_caption??'');
    final wasPaused=_paused;
    _pause(true);
    try {
      await showModalBottomSheet<void>(
        context:context,useSafeArea:true,isScrollControlled:true,
        backgroundColor:AppColors.background,
        shape:const RoundedRectangleBorder(
          borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
        builder:(sheetContext)=>Padding(
          padding:EdgeInsets.fromLTRB(20,20,20,
            MediaQuery.viewInsetsOf(sheetContext).bottom+24),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('Edit Moment caption',style:AppTypography.smallHeading),
              const SizedBox(height:12),
              TextField(controller:controller,maxLength:200,maxLines:3,
                decoration:const InputDecoration(hintText:'Your caption')),
              const SizedBox(height:16),
              AppPrimaryButton(label:'Save changes',onPressed:() async {
                try {
                  final newRevision=await widget.repository.updateCaption(
                    item,controller.text,version:_ownerPublishVersion);
                  if(!mounted || _current.id!=item.id)return;
                  setState((){
                    _caption=controller.text.trim();
                    _ownerPublishVersion=newRevision;
                  });
                  if(sheetContext.mounted)Navigator.of(sheetContext).pop();
                }catch(_){
                  if(mounted)_notice('Could not save this caption. Refresh if it changed elsewhere.');
                }
              }),
            ]),
        ),
      );
    } finally {
      controller.dispose();
      if(mounted)_pause(wasPaused);
    }
  }

  Future<void> _ownerActions() async {
    if(!_isOwner || !mounted)return;
    final wasPaused=_paused;_pause(true);
    try{await _ownerActionsBody();}finally{if(mounted)_pause(wasPaused);}
  }
  Future<void> _ownerActionsBody() async {
    final action=await showModalBottomSheet<String>(
      context:context,useSafeArea:true,
      backgroundColor:AppColors.background,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
      builder:(sheet)=>SingleChildScrollView(child:Padding(
        padding:const EdgeInsets.all(20),
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('Manage Moment',style:AppTypography.smallHeading),
          const SizedBox(height:12),
          ListTile(leading:const Icon(Icons.edit_outlined),
            title:Text('Edit caption',style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop('caption')),
          ListTile(leading:const Icon(Icons.people_outline_rounded),
            title:Text('Change audience',style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop('audience')),
          ListTile(leading:const Icon(Icons.person_add_alt_1_outlined),
            title:Text('Edit tagged people',style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop('tags')),
          ListTile(leading:const Icon(Icons.visibility_outlined),
            title:Text('View readers',style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop('viewers')),
          ListTile(leading:const Icon(Icons.delete_outline_rounded),
            title:Text('Delete Moment',style:AppTypography.body),
            onTap:()=>Navigator.of(sheet).pop('delete')),
        ]))),
    );
    if(!mounted)return;
    switch(action){
      case 'caption':await _ownerEditCaption();break;
      case 'audience':await _ownerChangeAudience();break;
      case 'tags':await _ownerEditTags();break;
      case 'viewers':await _ownerViewers();break;
      case 'delete':await _ownerDelete();break;
    }
  }

  Future<void> _ownerEditTags() async {
    if(!_isOwner||!mounted)return;
    final item=_current;
    final wasPaused=_paused;
    _pause(true);
    try{
      final eligible=await widget.repository.eligibleTagPeople(item);
      if(!mounted||_current.id!=item.id)return;
      final selected=<String>{..._ownerTags};
      bool saving=false;
      await showModalBottomSheet<void>(
        context:context,isScrollControlled:true,useSafeArea:true,
        backgroundColor:AppColors.background,
        shape:const RoundedRectangleBorder(
          borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
        builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet)=>Padding(
          padding:const EdgeInsets.all(20),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Tagged people',style:AppTypography.smallHeading),
            const SizedBox(height:8),
            Text('Tags are visible only within authorized audiences.',
              style:AppTypography.bodyMuted),
            const SizedBox(height:12),
            if(eligible.isEmpty)Text('No eligible friends to tag.',
              style:AppTypography.bodyMuted),
            if(eligible.isNotEmpty)ConstrainedBox(
              constraints:const BoxConstraints(maxHeight:280),
              child:ListView(shrinkWrap:true,children:[
                for(final person in eligible)CheckboxListTile(
                  title:Text(person.name,style:AppTypography.body),
                  value:selected.contains(person.id),
                  onChanged:saving?null:(value)=>setSheet((){
                    if(value==true && selected.length<20)selected.add(person.id);
                    else if(value!=true)selected.remove(person.id);
                  })),
              ])),
            const SizedBox(height:16),
            AppPrimaryButton(label:saving?'Saving…':'Save tags',
              onPressed:() async {
                if(saving)return;
                setSheet(()=>saving=true);
                try{
                  final revision=await widget.repository.updateTags(
                    item,selected,version:_ownerPublishVersion);
                  if(!mounted||_current.id!=item.id)return;
                  setState((){
                    _ownerPublishVersion=revision;
                    _ownerTags=selected;
                  });
                  if(sheet.mounted)Navigator.of(sheet).pop();
                }catch(_){
                  if(mounted)_notice('Tags could not be saved. Check permissions.');
                }finally{
                  if(sheet.mounted)setSheet(()=>saving=false);
                }
              }),
          ]),
        )),
      );
    }catch(_){if(mounted)_notice('Tagged people are unavailable.');}
    finally{if(mounted)_pause(wasPaused);}
  }

  Future<void> _ownerChangeAudience() async {
    if(!_isOwner || !mounted)return;
    final item=_current;
    final wasPaused=_paused;
    _pause(true);
    try{
      final options=await widget.repository.audienceOptions();
      if(!mounted || _current.id!=item.id)return;
      String kind=_ownerAudienceKind;
      final selected=<String>{..._ownerTargets};
      bool saving=false;
      final types=<({String kind,String label})>[
        (kind:'only_me',label:'Only Me'),
        if(options.friendsEnabled && options.friends.isNotEmpty)
          (kind:'accepted_friends',label:'All Friends'),
        if(options.friendsEnabled && options.friends.isNotEmpty)
          (kind:'selected_friends',label:'Selected Friends'),
        if(options.circlesEnabled && options.circles.isNotEmpty)
          (kind:'selected_circles',label:'Selected Circles'),
      ];
      if(!types.any((entry)=>entry.kind==kind)){
        kind='only_me';selected.clear();
      }
      await showModalBottomSheet<void>(
        context:context,isScrollControlled:true,useSafeArea:true,
        backgroundColor:AppColors.background,
        shape:const RoundedRectangleBorder(
          borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
        builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet){
          final targets=kind=='selected_circles'?options.circles:options.friends;
          final valid=kind=='only_me'||kind=='accepted_friends'||selected.isNotEmpty;
          return Padding(padding:const EdgeInsets.fromLTRB(20,20,20,24),
            child:ConstrainedBox(constraints:BoxConstraints(
              maxHeight:MediaQuery.sizeOf(sheet).height*0.75),
              child:Column(mainAxisSize:MainAxisSize.min,
                crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text('Change Moment audience',style:AppTypography.smallHeading),
                const SizedBox(height:12),
                Flexible(child:ListView(shrinkWrap:true,children:[
                  for(final choice in types)ListTile(
                    title:Text(choice.label,style:AppTypography.body),
                    leading:Icon(kind==choice.kind
                      ?Icons.radio_button_checked:Icons.radio_button_unchecked,
                      color:AppColors.primaryEnd),
                    onTap:saving?null:()=>setSheet((){
                      kind=choice.kind;selected.clear();
                    })),
                  if(kind=='selected_circles'||kind=='selected_friends')
                    Wrap(spacing:8,runSpacing:6,children:[
                      for(final target in targets)FilterChip(
                        label:Text(target.name,style:AppTypography.body),
                        selected:selected.contains(target.id),
                        onSelected:saving?null:(value)=>setSheet((){
                          if(value)selected.add(target.id);
                          else selected.remove(target.id);
                        })),
                    ]),
                ])),
                const SizedBox(height:16),
                AppPrimaryButton(label:saving?'Saving…':'Save audience',
                  onPressed:() async {
                    if(saving || !valid)return;
                    setSheet(()=>saving=true);
                    try {
                      final revision=await widget.repository.updateAudience(
                        item,kind,selected.toList(),
                        revision:_ownerAudienceRevision);
                      if(!mounted||_current.id!=item.id)return;
                      setState((){
                        _ownerAudienceRevision=revision;
                        _ownerAudienceKind=kind;
                        _ownerTargets=selected.toSet();
                      });
                      if(sheet.mounted)Navigator.of(sheet).pop();
                    }catch(_){
                      if(mounted)_notice('Audience could not be updated. Refresh and try again.');
                    }finally{
                      if(sheet.mounted)setSheet(()=>saving=false);
                    }
                  }),
              ])),
          );
        }),
      );
    }catch(_){if(mounted)_notice('Audience options are unavailable.');}
    finally{if(mounted)_pause(wasPaused);}
  }

  Future<void> _ownerDelete() async {
    if(!_isOwner || !mounted)return;
    final item=_current;
    await showDeleteMomentPopup(context,onDelete:() async {
      try {
        await widget.repository.delete(item);
        if(mounted)Navigator.of(context).maybePop();
      }catch(_){
        if(mounted)_notice('Moment deletion could not be confirmed.');
      }
    });
  }

  Future<void> _ownerViewers() async {
    if(!_isOwner || !mounted)return;
    final item=_current;
    try {
      // M3 read-receipt privacy and M7 context authorization are enforced
      // by the server. No public viewer count or cross-Circle roster.
      final receipts=await widget.repository.authorizedViewers(item);
      if(!mounted || _current.id!=item.id)return;
      final labels=<String>[];
      for(final receipt in receipts.take(30)){
        final id=receipt['viewer_id'] as String?;
        if(id==null)continue;
        try {labels.add(await widget.repository.name(id));}
        catch(_){labels.add('Orbit member');}
      }
      if(!mounted || _current.id!=item.id)return;
      await showModalBottomSheet<void>(
        context:context,useSafeArea:true,isScrollControlled:true,
        backgroundColor:AppColors.background,
        shape:const RoundedRectangleBorder(
          borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
        builder:(sheetContext)=>Padding(
          padding:const EdgeInsets.fromLTRB(20,20,20,24),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('Moment viewers',style:AppTypography.smallHeading),
              const SizedBox(height:8),
              Text('Only people who enabled read receipts appear here.',
                style:AppTypography.bodyMuted),
              const SizedBox(height:12),
              if(labels.isEmpty)
                Padding(padding:const EdgeInsets.symmetric(vertical:24),
                  child:Text('No eligible viewer receipts.',
                    style:AppTypography.bodyMuted)),
              if(labels.isNotEmpty)
                ConstrainedBox(constraints:const BoxConstraints(maxHeight:320),
                  child:ListView.builder(shrinkWrap:true,
                    itemCount:labels.length,itemBuilder:(_,index)=>ListTile(
                      leading:const Icon(Icons.person_outline_rounded,
                        color:AppColors.primaryEnd),
                      title:Text(labels[index],style:AppTypography.body)))),
            ]),
        ),
      );
    }catch(_){if(mounted)_notice('Viewer receipts are unavailable.');}
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor:AppColors.background,
      body:SafeArea(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:20),
        child:Column(children:[
          const SizedBox(height:20),
          if(widget.playlist.isNotEmpty&&!_allCaughtUp)...[
            _storyProgress(),const SizedBox(height:8),
          ],
          AppScreenHeader(title:_name,prominent:true),
          const SizedBox(height:20),
          Expanded(child:LayoutBuilder(builder:(context,limits)=>
            GestureDetector(
              behavior:HitTestBehavior.opaque,
              onTapUp:(event)=>_navigationTap(event,limits),
              onLongPressStart:(_)=>_pause(true),
              onLongPressEnd:(_){if(!_commentsOpen)_pause(false);},
              onVerticalDragEnd:(details){
                final speed=details.primaryVelocity??0;
                if(speed>350)Navigator.of(context).maybePop();
              },
              child:Center(child:_allCaughtUp
                ? Column(mainAxisSize:MainAxisSize.min,children:[
                    const Icon(Icons.check_circle_outline_rounded,
                      color:AppColors.primaryEnd,size:54),
                    const SizedBox(height:10),
                    Text('All caught up',style:AppTypography.smallHeading),
                    const SizedBox(height:12),
                    AppPrimaryButton(label:'Back to Moments',
                      onPressed:()=>Navigator.of(context).maybePop()),
                  ])
                : _loading
                ? const CircularProgressIndicator(color:AppColors.primaryEnd)
                : _error!=null
                  ? Text(_error!,textAlign:TextAlign.center,style:AppTypography.bodyMuted)
                  : ClipRRect(borderRadius:BorderRadius.circular(16),
                    child:_current.mediaKind=='image'
                      ? Image.memory(_photo!,fit:BoxFit.contain)
                      : OrbitPrivateMomentPlayer(
                          key:ValueKey<String>('m7_clip_${_current.id}'),
                          item:_current,repository:widget.repository,
                          paused:_paused,
                          previewBytes:_photo,
                          onProgress:(value){if(mounted)_clipProgress.value=value;},
                          onFinished:()=>_move(1)))),
            ))),
          if(!_allCaughtUp && _error==null && !_loading && _caption!=null&&_caption!.isNotEmpty &&
              WidgetsBinding.instance.lifecycleState!=AppLifecycleState.paused &&
              WidgetsBinding.instance.lifecycleState!=AppLifecycleState.inactive &&
              WidgetsBinding.instance.lifecycleState!=AppLifecycleState.hidden)
            Padding(padding:const EdgeInsets.symmetric(vertical:12),
              child:Text(_caption!,style:AppTypography.body)),
          if(!_allCaughtUp&&_error==null&&!_loading&&_commentsOpen)
            Flexible(flex:1,child:SingleChildScrollView(child:_commentsPanel())),
          if(!_allCaughtUp&&_error==null&&!_loading)
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
              const SizedBox(width:12),
              AppCircularIconButton(semanticLabel:'Share moment',onPressed:()=>unawaited(_share()),
                icon:Icons.share_outlined,iconSize:20,size:40),
              const Spacer(),
              if(_isOwner) ...[
                Tooltip(message:'Manage Moment',child:AppCircularIconButton(
                  semanticLabel:'Manage Moment',
                  onPressed:()=>unawaited(_ownerActions()),
                  icon:Icons.more_horiz_rounded,iconSize:20,size:40)),
              ] else ...[
                AppCircularIconButton(
                  semanticLabel:'Report Moment',
                  onPressed:()=>unawaited(_reportSheet()),
                  icon:Icons.flag_outlined,iconSize:20,size:40),
                const SizedBox(width:8),
                Tooltip(message:'Report account',child:AppCircularIconButton(
                  semanticLabel:'Report account',
                  onPressed:()=>unawaited(_reportSheet(account:true)),
                  icon:Icons.person_off_outlined,iconSize:20,size:40)),
              ],
            ]),
          const SizedBox(height:22),
        ]),
      )),
    );
  }
}
