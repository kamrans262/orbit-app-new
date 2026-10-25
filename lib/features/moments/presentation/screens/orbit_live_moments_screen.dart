import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';

import '../../data/orbit_moment_repository.dart';
import '../../../media/data/orbit_moment_media_stager.dart';
import '../../domain/models/moments_models.dart';
import '../screens/moment_camera_screen.dart';
import '../screens/moments_screen.dart';
import '../screens/orbit_live_moment_viewer.dart';

/// The authenticated replacement for MomentsScreen.demo. It passes real
/// server-authorized data to the existing styled MomentsScreen only.
class OrbitLiveMomentsScreen extends StatefulWidget {
  const OrbitLiveMomentsScreen({required this.onTabSelected,this.onAddPressed,
    this.circleId,this.profileId,super.key});
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onAddPressed;
  final String? circleId, profileId;
  @override
  State<OrbitLiveMomentsScreen> createState()=>_OrbitLiveMomentsScreenState();
}
class _OrbitLiveMomentsScreenState extends State<OrbitLiveMomentsScreen> with WidgetsBindingObserver {
  final OrbitMomentRepository _repo=OrbitMomentRepository();
  List<OrbitLiveMoment> _items=const [];
  List<OrbitLiveMoment> _rail=const [];
  final Map<String,Uint8List> _previews={};
  final Map<String,String> _names={};
  final Map<String,String> _captions={};
  final Map<String,String> _places={};
  OrbitMomentAudienceOptions _options=
    const OrbitMomentAudienceOptions([],[],'Nobody');
  final Set<String> _likes={};
  final Set<String> _bookmarked={};
  final Set<String> _seen={};
  bool _busy=true;
  String? _error;
  int _pendingPublishCount=0;
  String? _pendingWarning;
  bool _retrying=false;
  Timer? _authorizationRefresh;
  int _loadEpoch=0;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authorizationRefresh=Timer.periodic(const Duration(seconds:25),(_){
      if(!mounted || _busy ||
          WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed ||
          ModalRoute.of(context)?.isCurrent!=true)return;
      unawaited(_load());
    });
    unawaited(_load());
  }

  void _evictDecodedMedia() {
    for(final bytes in _previews.values) {
      unawaited(MemoryImage(bytes).evict());
    }
    _previews.clear();
    _captions.clear();
    _places.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.paused || state==AppLifecycleState.inactive) {
      ++_loadEpoch;
      if(mounted)setState((){
        _evictDecodedMedia();
        _items=const [];
        _rail=const [];
        _names.clear();
        _likes.clear();
        _bookmarked.clear();
        _seen.clear();
        _busy=true;
      });
    }else if(state==AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    ++_loadEpoch;
    _authorizationRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _evictDecodedMedia();
    super.dispose();
  }

  Future<void> _load() async {
    if(!mounted)return;
    final epoch=++_loadEpoch;
    setState((){_busy=true;_error=null;});
    try {
      // Resume only this account's encrypted outbox while foregrounded.
      // Failures leave the original ciphertext queued without fake success.

      String? pendingProblem;
      try{
        await _repo.resumePendingPublishes();
      }catch(_){
        pendingProblem='Waiting for connection or a secure retry';
      }
      var waiting=0;
      try{waiting=await _repo.pendingPublishCount();}catch(_){}
      if(waiting>0 && pendingProblem==null){
        try{pendingProblem=await _repo.pendingDraftNotice();}catch(_){}
      }
      if(mounted && epoch==_loadEpoch)setState((){
        _pendingPublishCount=waiting;
        _pendingWarning=pendingProblem;
      });
      final moments=await _repo.feed(maxItems:30,
        circleId:widget.circleId,profileId:widget.profileId);
      final rail=widget.circleId!=null||widget.profileId!=null
        ? moments.where((m)=>DateTime.now().difference(m.publishedAt)
          <const Duration(hours:24)).take(20).toList(growable:false)
        : await _repo.feed(rail:true,maxItems:20);
      OrbitMomentAudienceOptions options;
      try {options=await _repo.audienceOptions();}
      catch(_){options=const OrbitMomentAudienceOptions([],[],'Nobody');}
      final seen=await _repo.seenMomentIds(rail.map((m)=>m.id));
      final saved=await _repo.bookmarkedMomentIds(moments);
      final names=<String,String>{};
      final previews=<String,Uint8List>{};
      final captions=<String,String>{};
      final places=<String,String>{};
      final unique=<String>{};
      for(final m in [...rail,...moments]){
        if(!unique.add(m.id))continue;
        try {
          names[m.creatorId]??=await _repo.name(m.creatorId);
        }catch(_){names[m.creatorId]??='Orbit member';}
        try {
          previews[m.id]=await _repo.photo(m);
          final text=await _repo.caption(m);
          if(text!=null)captions[m.id]=text;
          final place=await _repo.place(m);
          if(place!=null)places[m.id]=place;
        }catch(_){
          // An expired or revoked key never uses an unauthenticated media URL.
        }
      }
      if(!mounted || epoch!=_loadEpoch){
        for(final bytes in previews.values)unawaited(MemoryImage(bytes).evict());
        return;
      }
      setState((){
        _evictDecodedMedia();
        _items=moments;_rail=rail;_options=options;
        _likes..clear()..addAll(moments.where((item)=>item.myReaction=='like').map((item)=>item.id));
        _bookmarked..clear()..addAll(saved);
        _previews..clear()..addAll(previews);
        _names..clear()..addAll(names);
        _seen..clear()..addAll(seen);
        _captions..clear()..addAll(captions);
        _places..clear()..addAll(places);
        _busy=false;
      });
    }catch(_){
      if(mounted && epoch==_loadEpoch)setState((){
        _evictDecodedMedia();
        _items=const [];
        _rail=const [];
        _names.clear();
        _likes.clear();
        _busy=false;
        _error='Unable to load encrypted Moments. Check your connection and try again.';
      });
    }
  }
  Future<void> _retryEncryptedDrafts() async {
    if(!mounted || _retrying)return;
    setState(()=>_retrying=true);
    try{
      await _repo.resumePendingPublishes(force:true);
      if(mounted)setState(()=>_pendingWarning=null);
    }catch(_){
      if(mounted)setState(()=>_pendingWarning=
        'Encrypted draft was not sent. Retry when connected.');
    }finally{
      if(mounted){
        setState(()=>_retrying=false);
        unawaited(_load());
      }
    }
  }
  Future<void> _discardUnrecoverable() async {
    if(!mounted || _retrying)return;
    await showDiscardMomentDraftPopup(context,onDiscard:() async {
      try{
        await _repo.discardUnrecoverableDrafts();
        if(mounted)unawaited(_load());
      }catch(_){
        if(mounted)setState(()=>_pendingWarning=
          'Encrypted drafts could not be discarded securely.');
      }
    });
  }

  String _relative(DateTime timestamp) {
    final d=DateTime.now().difference(timestamp);
    if(d.inMinutes<1)return 'Just now';
    if(d.inHours<1)return d.inMinutes.toString()+'m ago';
    if(d.inDays<1)return d.inHours.toString()+'h ago';
    return d.inDays.toString()+'d ago';
  }
  Future<void> _openViewer(OrbitLiveMoment item,
      {bool storyGroup=false}) async {
    if(!mounted)return;
    final source=storyGroup
      ? <OrbitLiveMoment>[..._rail,..._items] : _items;
    final found=<String>{};
    final playlist=(storyGroup
      ? source.where((m)=>m.creatorId==item.creatorId &&
          m.contextId==item.contextId)
      : source).where((m)=>found.add(m.id)).toList();
    if(!playlist.any((m)=>m.id==item.id))playlist.insert(0,item);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(moment:item,repository:_repo,
        author:_names[item.creatorId]??'Orbit member',
        authorNames:Map<String,String>.from(_names),
        playlist:playlist,
        initialIndex:playlist.indexWhere((m)=>m.id==item.id))));
    if(mounted)unawaited(_load());
  }
  void _openById(String id,{bool storyGroup=false}){
    for(final moment in [..._rail,..._items]){
      if(moment.id==id){
        unawaited(_openViewer(moment,storyGroup:storyGroup));return;
      }
    }
  }
  Future<void> _react(MomentImageFeedItem item,bool liked) async {
    OrbitLiveMoment? moment;
    for(final m in _items)if(m.id==item.id)moment=m;
    if(moment==null)return;
    try {
      await _repo.react(moment,liked:liked);
      if(mounted)setState((){
        if(liked)_likes.add(item.id);else _likes.remove(item.id);
      });
    }catch(_){if(mounted)unawaited(_load());}
  }
  Future<void> _setBookmark(MomentImageFeedItem item,bool saved) async {
    OrbitLiveMoment? current;
    for(final entry in _items)if(entry.id==item.id){current=entry;break;}
    if(current==null)return;
    try {
      await _repo.setBookmark(current,saved:saved);
      if(mounted)setState((){
        if(saved)_bookmarked.add(item.id);
        else _bookmarked.remove(item.id);
      });
    }catch(_){
      if(mounted)unawaited(_load());
    }
  }

  MomentCameraScreen _camera() => MomentCameraScreen(
    privateSaver:(bytes,progress) async {
      final saved=await OrbitMomentMediaStager()
        .stagePhoto(bytes,onProgress:progress);
      if(!saved.thumbnailVerified || !saved.privateGrantConfirmed){
        throw StateError('Private encrypted storage not confirmed.');
      }
    },
    momentAudienceCircles:_options.circles,
    momentAudienceFriends:_options.friends,
    momentPrivacyAudience:_options.privacy,
    publishMoment:(request,progress) async {
      final receipt=await _repo.publish(request,progress);
      unawaited(_load());
      return receipt;
    },
  );
  @override
  Widget build(BuildContext context){
    final groups=<String,OrbitLiveMoment>{};
    final groupUnseen=<String,bool>{};
    final newestInContext=<String,DateTime>{};
    for(final m in _rail){
      final groupKey=m.contextId+'|'+m.creatorId;
      groups.putIfAbsent(groupKey,()=>m);
      final previous=newestInContext[m.contextId];
      if(previous==null || m.publishedAt.isAfter(previous)){
        newestInContext[m.contextId]=m.publishedAt;
      }
      groupUnseen[groupKey]=(groupUnseen[groupKey]??false) ||
        !_seen.contains(m.id);
    }
    // Preserve the internal Circle -> sender organization, with Circles
    // ordered by newest eligible content and senders newest first.
    final grouped=groups.values.toList()..sort((a,b){
      final byContext=newestInContext[b.contextId]!
        .compareTo(newestInContext[a.contextId]!);
      if(byContext!=0)return byContext;
      final byCircle=a.contextId.compareTo(b.contextId);
      if(byCircle!=0)return byCircle;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    final stories=<MomentStoryData>[
      const MomentStoryData(id:'add',name:'You',isAddStory:true),
      for(final m in grouped)MomentStoryData(
        id:m.id,name:_names[m.creatorId]??'Orbit member',
        imageBytes:_previews[m.id],
        isCircle:m.contextId.startsWith('circle:'),
        isUnseen:groupUnseen[m.contextId+'|'+m.creatorId]??false),
    ];
    final feed=<MomentFeedItem>[
      for(final m in _items)MomentImageFeedItem(
        id:m.id,
        author:MomentAuthorData(id:m.creatorId,
          name:_names[m.creatorId]??'Orbit member'),
        timeLabel:_relative(m.publishedAt),
        imagePath:null,imageBytes:_previews[m.id],
        title:_captions[m.id]??'',
        location:_places[m.id]??'',
        likeCount:0,commentCount:0,countsKnown:false,
        isLiked:_likes.contains(m.id),
        isBookmarked:_bookmarked.contains(m.id),
      ),
    ];
    return Stack(children:[
      MomentsScreen(
      key:const Key('orbit_m7_live_moments'),
      stories:stories,feedItems:feed,privateMode:true,
      privateBookmarking:true,
      viewState:_busy?MomentsViewState.loading:
        _error!=null?MomentsViewState.error:
        feed.isEmpty?MomentsViewState.empty:MomentsViewState.populated,
      errorMessage:_error??'Moments unavailable.',
      onSearchPressed:(){},onFilterPressed:()=>unawaited(_load()),
      onMessagesPressed:(){},
      onStoryPressed:(story)=>_openById(story.id,storyGroup:true),
      onLikeChanged:(item,liked)=>unawaited(_react(item,liked)),
      onCommentPressed:(item)=>_openById(item.id),
      onBookmarkChanged:(item,value)=>unawaited(_setBookmark(item,value)),
      onSharePressed:(item){},
      onTextMenuPressed:(item){},
      onFeedItemPressed:(item)=>_openById(item.id),
      onTabSelected:widget.onTabSelected,onAddPressed:(){},
      cameraBuilder:(_)=>_camera(),
    ),
    if(_pendingPublishCount>0)Positioned(
      bottom:90,left:16,right:16,
      child:Material(
        color:AppColors.background,
        elevation:4,
        borderRadius:BorderRadius.circular(20),
        child:Padding(
          padding:const EdgeInsets.all(12),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(
              _pendingWarning??'$_pendingPublishCount encrypted Moment draft(s) waiting to send',
              textAlign:TextAlign.center,style:AppTypography.body),
            const SizedBox(height:8),
            if((_pendingWarning??'').startsWith('Draft needs review') ||
                (_pendingWarning??'').startsWith('Encrypted draft is incomplete'))
              AppPrimaryButton(label:'Discard unrecoverable draft',
                enabled:!_retrying,
                onPressed:()=>unawaited(_discardUnrecoverable()))
            else
              AppPrimaryButton(
                label:_retrying?'Sending…':'Retry encrypted draft',
                enabled:!_retrying,
                onPressed:()=>unawaited(_retryEncryptedDrafts())),
          ]),
        ),
      ),
    ),
    ]);
  }
}
