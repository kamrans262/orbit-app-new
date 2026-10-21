import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../data/orbit_circle_repository.dart';
import '../../domain/models/friend_details_models.dart';
import 'friend_details_screen.dart';
import 'orbit_live_circle_settings_screen.dart';
import 'orbit_live_invite_member_screen.dart';

class OrbitLiveCircleDetailScreen extends StatefulWidget {
  const OrbitLiveCircleDetailScreen({required this.circleId,super.key,this.repository});
  final String circleId;
  final OrbitCircleRepository? repository;
  @override
  State<OrbitLiveCircleDetailScreen> createState() => _OrbitLiveCircleDetailScreenState();
}

class _OrbitLiveCircleDetailScreenState extends State<OrbitLiveCircleDetailScreen>
    with WidgetsBindingObserver {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  OrbitCircle? _circle;
  List<OrbitCircleMember> _members = const [];
  bool _loading = true;
  String? _error;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final epoch=++_epoch;
    if(mounted) setState(() {_loading=true;_error=null;});
    try {
      final circle=await _repo.detail(widget.circleId);
      final members=<OrbitCircleMember>[];
      for (var p=1;p<=20;p++) {
        final result=await _repo.members(widget.circleId,page:p);
        members.addAll(result.items);
        if(!result.hasMore) break;
      }
      if(!mounted || epoch!=_epoch) return;
      setState(() {_circle=circle; _members=members; _loading=false;});
    } catch (_) {
      if(!mounted || epoch!=_epoch) return;
      setState(() {
        _circle=null;_members=const [];
        _error='Circle access could not be verified. Reconnect or return to My Circles.';
        _loading=false;
      });
    }
  }

  Future<void> _memberPreview(OrbitCircleMember member) async {
    if(_circle==null) return;
    await showModalBottomSheet<void>(context:context,
      backgroundColor:AppColors.background,
      builder:(context)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(20),
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('Circle member',style:TextStyle(
              fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w600,fontSize:18)),
            const SizedBox(height:12),
            Text(member.name),
            if(member.username.isNotEmpty)Text('@${member.username}'),
            Text('Role: ${member.role}'),
            const SizedBox(height:12),
            const Text('Live presence and location are not shared.',
              style:TextStyle(color:Color(0xFF64748B),fontSize:12)),
          ],
        ),
      )));
  }

  Future<void> _openInvite() async {
    final circle=_circle;
    if(circle==null || !circle.can('invite')) return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder: (_) => OrbitLiveInviteMemberScreen(
        circleId:circle.id,repository:_repo)));
    if(mounted) await _refresh();
  }

  Future<void> _openSettings() async {
    final circle=_circle;
    if(circle==null) return;
    final outcome=await Navigator.of(context).push<String>(
      AppFadeSlidePageRoute<String>(
        builder: (_) => OrbitLiveCircleSettingsScreen(
          circle:circle,repository:_repo)));
    if(!mounted)return;
    if(outcome=='unavailable') {
      Navigator.of(context).maybePop();
      return;
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    FriendDetailsScreen(
      circleName: _circle?.name ?? 'Circle',
      members: _members.map((p) => FriendMemberData(
        id:p.id,name:p.name,
        status:'${p.username.isEmpty ? p.role : '@${p.username} • ${p.role}'}',
        imagePath:null,
        onTap:()=>_memberPreview(p),
      )).toList(growable:false),
      groups:const <CircleGroupData>[],
      onBack: () => Navigator.of(context).maybePop(),
      onAddMember: _openInvite,
      liveInviteMode: true,
      headerTitle:'Circle Details',
      showGroupSegment:false,
      showFavoriteActions:false,
      showAddMemberButton: _circle?.can('invite') == true,
      viewState:_loading ? FriendDetailsViewState.loading
        : _error!=null ? FriendDetailsViewState.error
        : FriendDetailsViewState.loaded,
      errorMessage:_error ?? 'Unable to load Circle members.',
      onRetry:_refresh,
    ),
    if(!_loading && _circle!=null)
      Positioned(right:20,bottom:25,
        child: FloatingActionButton.extended(
          heroTag:'m5-circle-settings',
          backgroundColor:AppColors.background,
          foregroundColor:const Color(0xFF7C3AED),
          onPressed:_openSettings,
          label:const Text('Circle settings'),
          icon:const Icon(Icons.settings_outlined),
        )),
  ]);
}
