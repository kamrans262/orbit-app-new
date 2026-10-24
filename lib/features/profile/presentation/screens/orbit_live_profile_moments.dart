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
  const OrbitLiveProfileMoments({required this.profileId,super.key});
  final String profileId;
  @override
  State<OrbitLiveProfileMoments> createState()=>_OrbitLiveProfileMomentsState();
}
class _OrbitLiveProfileMomentsState extends State<OrbitLiveProfileMoments> {
  final OrbitMomentRepository _repo=OrbitMomentRepository();
  final List<OrbitLiveMoment> _authorized=[];
  final Map<String,Uint8List> _images={};
  bool _loading=true;
  String? _error;

  @override
  void initState(){super.initState();unawaited(_reload());}

  Future<void> _reload() async {
    if(mounted)setState((){_loading=true;_error=null;});
    try{
      final feed=await _repo.feed(profileId:widget.profileId,maxItems:40);
      final shown=<OrbitLiveMoment>[];
      final pics=<String,Uint8List>{};
      for(final moment in feed) {
        try {
          final thumb=await _repo.photo(moment);
          pics[moment.id]=thumb;
          shown.add(moment);
        }catch(_){
          // Revoked, blocked and expired Moments do not create a tile.
        }
      }
      if(!mounted)return;
      setState((){
        _authorized..clear()..addAll(shown);
        _images..clear()..addAll(pics);
        _loading=false;
      });
    }catch(_){
      if(mounted)setState((){
        _error='Your Moments are unavailable. Check your connection.';
        _loading=false;
      });
    }
  }

  Future<void> _open(OrbitLiveMoment moment) async {
    if(!mounted)return;
    final current=_authorized.indexWhere((m)=>m.id==moment.id);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(
        moment:moment,repository:_repo,author:'You',
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
