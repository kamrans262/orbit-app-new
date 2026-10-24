import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../data/orbit_moment_repository.dart';
import '../widgets/orbit_private_moment_player.dart';

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

class _OrbitLiveMomentViewerState extends State<OrbitLiveMomentViewer> with WidgetsBindingObserver {
  Uint8List? _photo;
  String? _caption;
  String? _error;
  bool _loading=true, _liked=false, _sending=false, _paused=false;
  bool _allCaughtUp=false;
  bool _isOwner=false;
  bool _reauthorizing=false;
  Timer? _advance;
  Timer? _revalidation;
  int _loadEpoch=0;
  late int _index;
  OrbitLiveMoment get _current => widget.playlist.isEmpty
      ? widget.moment : widget.playlist[_index];
  String get _name => widget.authorNames[_current.creatorId]??widget.author;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index=widget.playlist.isEmpty?0:widget.initialIndex.clamp(0,widget.playlist.length-1);
    _revalidation=Timer.periodic(const Duration(seconds:20),(_){
      if(!mounted || _loading || _error!=null ||
          (WidgetsBinding.instance.lifecycleState==AppLifecycleState.paused ||
           WidgetsBinding.instance.lifecycleState==AppLifecycleState.inactive ||
           WidgetsBinding.instance.lifecycleState==AppLifecycleState.hidden) ||
          ModalRoute.of(context)?.isCurrent!=true)return;
      unawaited(_checkAuthorization());
    });
    unawaited(_load());
  }

  void _forgetPhoto(){
    final bytes=_photo;
    if(bytes!=null)unawaited(MemoryImage(bytes).evict());
    _photo=null;
    _caption=null;
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
    if(!valid){
      _advance?.cancel();
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
      _advance?.cancel();
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
    ++_loadEpoch;
    _advance?.cancel();
    _revalidation?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _forgetPhoto();
    super.dispose();
  }
  void _schedule(){
    _advance?.cancel();
    if(widget.playlist.isEmpty||_paused||_loading||_error!=null ||
        _allCaughtUp ||
        (MediaQuery.maybeOf(context)?.disableAnimations??false))return;
    if(_current.mediaKind=='image'){
      _advance=Timer(const Duration(seconds:5),()=>_move(1));
    }
  }
  void _move(int amount){
    if(!mounted || widget.playlist.isEmpty)return;
    final to=_index+amount;
    if(to<0)return;
    if(to>=widget.playlist.length){
      _advance?.cancel();
      setState((){
        _forgetPhoto();
        _allCaughtUp=true;
      });
      return;
    }
    _advance?.cancel();
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
    if(value)_advance?.cancel();else _schedule();
  }
  void _navigationTap(TapUpDetails tap,BoxConstraints constraints){
    if(widget.playlist.isEmpty)return;
    _move(tap.localPosition.dx<constraints.maxWidth/2?-1:1);
  }
  Future<void> _load() async {
    final epoch=++_loadEpoch;
    if(!mounted)return;
    setState((){
      _advance?.cancel();
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
      final photo=current.mediaKind=='image'
        ? await widget.repository.photo(current,variant:'original')
        : current.mediaKind=='audio'
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
          _isOwner=viewer!=null && viewer==current.creatorId;
          _loading=false;
        });
        _schedule();
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
                  trailing:IconButton(
                    tooltip:'Report this private comment',
                    icon:const Icon(Icons.flag_outlined),
                    onPressed:(){
                      final commentId=lines[index].id;
                      Navigator.of(sheetContext).pop();
                      unawaited(_reportSheet(commentId:commentId));
                    },
                  ),
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
  Future<void> _reportSheet({String? commentId,bool account=false}) async {
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
    try{
      await widget.repository.report(_current,code,
        commentId:commentId,account:account);
      if(mounted)_notice('Your report has been submitted.');
    }catch(_){if(mounted)_notice('Unable to submit this report.');}
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
                          onFinished:()=>_move(1)))),
            ))),
          if(_error==null && !_loading && _caption!=null&&_caption!.isNotEmpty &&
              WidgetsBinding.instance.lifecycleState!=AppLifecycleState.paused &&
              WidgetsBinding.instance.lifecycleState!=AppLifecycleState.inactive &&
              WidgetsBinding.instance.lifecycleState!=AppLifecycleState.hidden)
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
              if(_isOwner) ...[
                AppCircularIconButton(
                  semanticLabel:'View Moment viewers',
                  onPressed:()=>unawaited(_ownerViewers()),
                  icon:Icons.visibility_outlined,iconSize:20,size:40),
                const SizedBox(width:8),
                AppCircularIconButton(
                  semanticLabel:'Delete this Moment',
                  onPressed:()=>unawaited(_ownerDelete()),
                  icon:Icons.delete_outline_rounded,iconSize:20,size:40),
                const SizedBox(width:8),
              ],
              AppCircularIconButton(
                semanticLabel:'Report Moment',
                onPressed:()=>unawaited(_reportSheet()),
                icon:Icons.flag_outlined,iconSize:20,size:40),
              const SizedBox(width:8),
              AppCircularIconButton(
                semanticLabel:'Report account',
                onPressed:()=>unawaited(_reportSheet(account:true)),
                icon:Icons.person_off_outlined,iconSize:20,size:40),
            ]),
          const SizedBox(height:22),
        ]),
      )),
    );
  }
}
