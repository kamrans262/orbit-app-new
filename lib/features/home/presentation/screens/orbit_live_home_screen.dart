import 'dart:async';
import '../../../auth/data/orbit_identity_client.dart';
import 'package:flutter/material.dart';

import '../../../moments/data/orbit_moment_repository.dart';
import '../../../moments/presentation/screens/orbit_live_moment_viewer.dart';
import '../../../moments/presentation/screens/orbit_live_moments_screen.dart';
import '../../../moments/presentation/screens/orbit_live_moment_notifications_screen.dart';
import '../../domain/models/home_models.dart';
import 'home_screen.dart';

/// Authenticated Home stays visually identical to approved HomeScreen.
/// Recent Moments use authorized decrypted data, not example people/photos.
class OrbitLiveHomeScreen extends StatefulWidget {
  const OrbitLiveHomeScreen({super.key});
  @override
  State<OrbitLiveHomeScreen> createState()=>_OrbitLiveHomeScreenState();
}
class _OrbitLiveHomeScreenState extends State<OrbitLiveHomeScreen> {
  final OrbitMomentRepository _moments=OrbitMomentRepository();
  List<MomentData> _recent=const [];
  String _greeting='';
  final Map<String,OrbitLiveMoment> _byId={};
  final Map<String,String> _authors={};
  @override
  void initState(){
    super.initState();
    unawaited(_reload());
  }
  Future<void> _reload() async {
    try {
      try {
        final person=await OrbitIdentityClient.instance.currentUser();
        final data=person['data'];
        if(data is Map && data['display_name'] is String && mounted){
          setState(()=>_greeting=data['display_name'] as String);
        }
      }catch(_){}
      final rail=await _moments.feed(rail:true);
      final visible=<MomentData>[];
      final authorized=<String,OrbitLiveMoment>{};
      final authors=<String,String>{};
      for(final moment in rail) {
        if(visible.length==3)break;
        try {
          final thumbnail=await _moments.photo(moment);
          final name=await _moments.name(moment.creatorId);
          final age=DateTime.now().difference(moment.publishedAt);
          final label=age.inMinutes<1?'Just now':
              age.inHours<1?age.inMinutes.toString()+'m ago':
              age.inHours.toString()+'h ago';
          visible.add(MomentData(id:moment.id,name:name,timeLabel:label,
            imagePath:'',encryptedImageBytes:thumbnail));
          authorized[moment.id]=moment;
          authors[moment.id]=name;
        }catch(_) {
          // A revoked/expired Moment must not show placeholder details.
        }
      }
      if(!mounted)return;
      setState((){
        _recent=visible;
        _byId..clear()..addAll(authorized);
        _authors..clear()..addAll(authors);
      });
    } catch (_) {
      if(mounted)setState((){
        _recent=const [];
        _byId.clear();
        _authors.clear();
      });
    }
  }
  Future<void> _view(MomentData data) async {
    final moment=_byId[data.id];
    if(moment==null || !mounted)return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(
        moment:moment,repository:_moments,
        author:_authors[data.id]??'Orbit member')));
    if(mounted)unawaited(_reload());
  }
  Future<void> _openNotices() async {
    if(!mounted)return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>const OrbitLiveMomentNotificationsScreen()));
    if(mounted)unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) => HomeScreen(
    greetingName:_greeting,
    useLiveDate:true,
    quickActions:const <QuickActionData>[
      QuickActionData(id:'moment',title:'Moment',
        icon:Icons.photo_camera_outlined,
        iconColor:Color(0xFF16B88B),iconBackground:Color(0xFFE2F8F2)),
    ],
    upcomingPlans:const <UpcomingPlanData>[],
    promoBanner:null,
    favoritePeople:const <FavoritePersonData>[],
    recentMoments:_recent,
    onNotificationPressed:()=>unawaited(_openNotices()),
    onQuickActionPressed:(action){
      if(action.id=='moment') {
        // Native capture is already wired through Orbit's existing launcher.
        Navigator.of(context).push<void>(MaterialPageRoute(
          builder:(_)=>OrbitLiveMomentsScreen(onTabSelected:(_){},
            onAddPressed:(){})));
      }
    },
    onPlanPressed:(_){},
    onPromoPressed:(){},
    onFavoritePersonPressed:(_){},
    onFavoriteToggle:(_){},
    onMomentPressed:(moment)=>unawaited(_view(moment)),
    onTabSelected:(_){},
    onAddPressed:(){},
    enableDemoCircleNavigation:false,
  );
}
