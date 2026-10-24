import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../welcome/presentation/screens/create_circle_screen.dart';
import '../../data/orbit_circle_repository.dart';
import 'orbit_live_circle_detail_screen.dart';

class OrbitLiveCreateCircleScreen extends StatefulWidget {
  const OrbitLiveCreateCircleScreen({super.key,this.repository,this.onCreated});
  final OrbitCircleRepository? repository;
  final ValueChanged<OrbitCircle>? onCreated;
  @override
  State<OrbitLiveCreateCircleScreen> createState()=>_OrbitLiveCreateCircleScreenState();
}

class _OrbitLiveCreateCircleScreenState extends State<OrbitLiveCreateCircleScreen> {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  OrbitCircle? _created;
  bool _allowTemporary=false;

  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    try {
      final features=await _repo.features();
      if(mounted) setState(()=>_allowTemporary=features['temporary_circles']==true);
    } catch (_) {
      // Hide optional temporary mode rather than offering an unavailable API.
      if(mounted)setState(()=>_allowTemporary=false);
    }
  }

  @override
  Widget build(BuildContext context)=>CreateCircleScreen(
    enableTemporary:_allowTemporary,
    onCreateRequested:(name,color,icon,key,expiresAt) async {
      _created=await _repo.create(name,color:color,icon:icon,
        idempotencyKey:key,expiresAt:expiresAt);
      if(_created!=null)widget.onCreated?.call(_created!);
    },
    onNext:(){
      final circle=_created;
      if(circle==null)return;
      Navigator.of(context).pushReplacement<void,void>(
        AppFadeSlidePageRoute<void>(builder:(_)=>
          OrbitLiveCircleDetailScreen(circleId:circle.id,repository:_repo)),
      );
    },
    onSkip:()=>Navigator.of(context).maybePop(),
  );
}
