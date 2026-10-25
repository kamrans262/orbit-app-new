import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../moments/data/orbit_moment_repository.dart';
import '../../../moments/presentation/screens/orbit_live_moment_viewer.dart';
import '../../domain/models/profile_models.dart';
import '../widgets/profile_moment_tile.dart';

/// Uses the approved Profile Moment tile and masonry grid. Nothing is public:
/// each original and thumbnail requires M3/M5/M6/M7 authorization.
class OrbitLiveProfileMoments extends StatefulWidget {
  const OrbitLiveProfileMoments({
    this.profileId,this.circleId,this.repository,super.key,
  }) : assert((profileId==null)!=(circleId==null),
    'Select exactly one private Moment context.');
  final String? profileId,circleId;
  final OrbitMomentRepository? repository;

  @override
  State<OrbitLiveProfileMoments> createState()=>_OrbitLiveProfileMomentsState();
}

class _OrbitLiveProfileMomentsState extends State<OrbitLiveProfileMoments>
    with WidgetsBindingObserver {
  late final OrbitMomentRepository _repo=widget.repository??OrbitMomentRepository();
  final List<OrbitLiveMoment> _authorized=[];
  final Map<String,Uint8List> _images={};
  bool _loading=true;
  String? _error;
  int _epoch=0;
  Timer? _authorizationTimer;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authorizationTimer=Timer.periodic(const Duration(seconds:25),(_){
      if(!mounted || _loading ||
        WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent!=true)return;
      unawaited(_reload());
    });
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant OrbitLiveProfileMoments old){
    super.didUpdateWidget(old);
    if(old.profileId!=widget.profileId||old.circleId!=widget.circleId){
      ++_epoch;
      _discardMedia();
      unawaited(_reload());
    }
  }

  void _discardMedia(){
    for(final bytes in _images.values){
      unawaited(MemoryImage(bytes).evict());
    }
    _images.clear();
    _authorized.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.inactive ||
       state==AppLifecycleState.hidden ||
       state==AppLifecycleState.paused){
      ++_epoch;
      if(mounted)setState((){
        _discardMedia();
        _loading=true;
      });
    }else if(state==AppLifecycleState.resumed && mounted){
      unawaited(_reload());
    }
  }

  @override
  void dispose(){
    ++_epoch;
    _authorizationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _discardMedia();
    super.dispose();
  }

  Future<void> _reload() async {
    if(!mounted)return;
    final epoch=++_epoch;
    setState((){
      _discardMedia(); // Never render stale content during ACL revalidation.
      _loading=true;_error=null;
    });
    final pics=<String,Uint8List>{};
    try{
      final feed=await _repo.feed(
        profileId:widget.profileId,circleId:widget.circleId,maxItems:40);
      final shown=<OrbitLiveMoment>[];
      for(final moment in feed){
        if(!mounted || epoch!=_epoch)break;
        try{
          final thumb=await _repo.photo(moment);
          // Permission could change while the download/decrypt was running.
          if(!await _repo.remainsAuthorized(moment)){
            unawaited(MemoryImage(thumb).evict());
            continue;
          }
          if(!mounted || epoch!=_epoch){
            unawaited(MemoryImage(thumb).evict());
            break;
          }
          pics[moment.id]=thumb;
          shown.add(moment);
        }catch(_){
          // A denied or expired Moment never leaves a stale public thumbnail.
        }
      }
      if(!mounted || epoch!=_epoch)return;
      setState((){
        _authorized..clear()..addAll(shown);
        _images..clear()..addAll(pics);
        _loading=false;
      });
    }catch(_){
      if(mounted && epoch==_epoch)setState((){
        _discardMedia();
        _error='Moments are unavailable. Check your connection.';
        _loading=false;
      });
    }finally{
      if(!mounted||epoch!=_epoch){
        for(final bytes in pics.values)unawaited(MemoryImage(bytes).evict());
      }
    }
  }

  Future<void> _open(OrbitLiveMoment moment) async {
    if(!mounted || !await _repo.remainsAuthorized(moment)){
      if(mounted)unawaited(_reload());
      return;
    }
    final current=_authorized.indexWhere((m)=>m.id==moment.id);
    if(current<0)return;
    String author='Orbit member';
    try{author=await _repo.name(moment.creatorId);}catch(_){}
    if(!mounted)return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(
        moment:moment,repository:_repo,author:author,
        playlist:List<OrbitLiveMoment>.from(_authorized),
        initialIndex:current),
    ));
    if(mounted)unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    if(_loading)return const Center(child:Padding(
      padding:EdgeInsets.all(24),
      child:CircularProgressIndicator(color:AppColors.primaryEnd)));
    if(_error!=null)return Column(children:[
      Text(_error!,style:AppTypography.bodyMuted,textAlign:TextAlign.center),
      TextButton(onPressed:()=>unawaited(_reload()),
        child:const Text('Try again')),
    ]);
    if(_authorized.isEmpty)return const Padding(
      padding:EdgeInsets.all(22),
      child:Text('No Moments yet',textAlign:TextAlign.center,
        style:TextStyle(fontFamily:AppTypography.fontFamily,
          color:AppColors.textMuted,fontSize:14)));
    return MasonryGridView.count(
      physics:const NeverScrollableScrollPhysics(),shrinkWrap:true,
      crossAxisCount:2,mainAxisSpacing:8,crossAxisSpacing:8,
      itemCount:_authorized.length,
      itemBuilder:(context,i) {
        final item=_authorized[i];
        return ProfileMomentTile(
          key:ValueKey<String>('m7_profile_'+item.id),
          moment:ProfileMomentData(id:item.id,
            imageBytes:_images[item.id],aspectRatio:0.9),
          onTap:()=>unawaited(_open(item)),
        );
      },
    );
  }
}
