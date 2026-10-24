import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/orbit_moment_repository.dart';
import '../../domain/models/moments_models.dart';
import '../screens/moment_camera_screen.dart';
import '../screens/moments_screen.dart';
import '../screens/orbit_live_moment_viewer.dart';

/// The authenticated replacement for MomentsScreen.demo. It passes real
/// server-authorized data to the existing styled MomentsScreen only.
class OrbitLiveMomentsScreen extends StatefulWidget {
  const OrbitLiveMomentsScreen({required this.onTabSelected,this.onAddPressed,super.key});
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onAddPressed;
  @override
  State<OrbitLiveMomentsScreen> createState()=>_OrbitLiveMomentsScreenState();
}
class _OrbitLiveMomentsScreenState extends State<OrbitLiveMomentsScreen> {
  final OrbitMomentRepository _repo=OrbitMomentRepository();
  List<OrbitLiveMoment> _items=const [];
  List<OrbitLiveMoment> _rail=const [];
  final Map<String,Uint8List> _previews={};
  final Map<String,String> _names={};
  final Map<String,String> _captions={};
  OrbitMomentAudienceOptions _options=
    const OrbitMomentAudienceOptions([],[],'Nobody');
  final Set<String> _likes={};
  bool _busy=true;
  String? _error;

  @override
  void initState(){
    super.initState();
    unawaited(_load());
  }
  Future<void> _load() async {
    if(mounted)setState((){_busy=true;_error=null;});
    try {
      final moments=await _repo.feed();
      final rail=await _repo.feed(rail:true);
      OrbitMomentAudienceOptions options;
      try {options=await _repo.audienceOptions();}
      catch(_){options=const OrbitMomentAudienceOptions([],[],'Nobody');}
      final names=<String,String>{};
      final previews=<String,Uint8List>{};
      final captions=<String,String>{};
      for(final m in moments){
        try {
          names[m.creatorId]??=await _repo.name(m.creatorId);
        }catch(_){names[m.creatorId]??='Orbit member';}
        try {
          previews[m.id]=await _repo.photo(m);
          final text=await _repo.caption(m);
          if(text!=null)captions[m.id]=text;
        }catch(_){
          // An expired or revoked key never uses an unauthenticated media URL.
        }
      }
      if(!mounted)return;
      setState((){
        _items=moments;_rail=rail;_options=options;
        _previews..clear()..addAll(previews);
        _names..clear()..addAll(names);
        _captions..clear()..addAll(captions);
        _busy=false;
      });
    }catch(_){
      if(mounted)setState((){
        _busy=false;
        _error='Unable to load encrypted Moments. Check your connection and try again.';
      });
    }
  }
  String _relative(DateTime timestamp) {
    final d=DateTime.now().difference(timestamp);
    if(d.inMinutes<1)return 'Just now';
    if(d.inHours<1)return d.inMinutes.toString()+'m ago';
    if(d.inDays<1)return d.inHours.toString()+'h ago';
    return d.inDays.toString()+'d ago';
  }
  Future<void> _openViewer(OrbitLiveMoment item) async {
    if(!mounted)return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(moment:item,repository:_repo,
        author:_names[item.creatorId]??'Orbit member')));
    if(mounted)unawaited(_load());
  }
  void _openById(String id){
    for(final moment in _items){
      if(moment.id==id){unawaited(_openViewer(moment));return;}
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
  MomentCameraScreen _camera() => MomentCameraScreen(
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
    final stories=<MomentStoryData>[
      const MomentStoryData(id:'add',name:'You',isAddStory:true),
      for(final m in _rail)MomentStoryData(
        id:m.id,name:_names[m.creatorId]??'Orbit member',
        imageBytes:_previews[m.id]),
    ];
    final feed=<MomentFeedItem>[
      for(final m in _items)MomentImageFeedItem(
        id:m.id,
        author:MomentAuthorData(id:m.creatorId,
          name:_names[m.creatorId]??'Orbit member'),
        timeLabel:_relative(m.publishedAt),
        imagePath:null,imageBytes:_previews[m.id],
        title:_captions[m.id]??'',
        location:'',
        likeCount:0,commentCount:0,countsKnown:false,
        isLiked:_likes.contains(m.id),
      ),
    ];
    return MomentsScreen(
      key:const Key('orbit_m7_live_moments'),
      stories:stories,feedItems:feed,privateMode:true,
      viewState:_busy?MomentsViewState.loading:
        _error!=null?MomentsViewState.error:
        feed.isEmpty?MomentsViewState.empty:MomentsViewState.populated,
      errorMessage:_error??'Moments unavailable.',
      onSearchPressed:(){},onFilterPressed:()=>unawaited(_load()),
      onMessagesPressed:(){},
      onStoryPressed:(story)=>_openById(story.id),
      onLikeChanged:(item,liked)=>unawaited(_react(item,liked)),
      onCommentPressed:(item)=>_openById(item.id),
      onBookmarkChanged:(item,value){},
      onSharePressed:(item){},
      onTextMenuPressed:(item){},
      onFeedItemPressed:(item)=>_openById(item.id),
      onTabSelected:widget.onTabSelected,onAddPressed:(){},
      cameraBuilder:(_)=>_camera(),
    );
  }
}
