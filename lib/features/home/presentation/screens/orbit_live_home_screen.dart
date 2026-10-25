import 'dart:async';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../../friends/presentation/screens/orbit_person_screen.dart';
import 'package:flutter/material.dart';

import '../../../moments/data/orbit_moment_repository.dart';
import '../../../moments/data/orbit_m7_rollout.dart';
import '../../../moments/data/orbit_moment_push_runtime.dart';
import '../../../moments/presentation/screens/orbit_live_moment_viewer.dart';
import '../../../moments/presentation/screens/orbit_live_moments_screen.dart';
import '../../../moments/presentation/screens/orbit_live_moment_notifications_screen.dart';
import '../../domain/models/home_models.dart';
import '../../data/orbit_home_demo_fixture.dart';
import 'home_screen.dart';

/// Authenticated Home stays visually identical to approved HomeScreen.
/// Recent Moments use authorized decrypted data, not example people/photos.
class OrbitLiveHomeScreen extends StatefulWidget {
  const OrbitLiveHomeScreen({super.key});
  @override
  State<OrbitLiveHomeScreen> createState()=>_OrbitLiveHomeScreenState();
}
class _OrbitLiveHomeScreenState extends State<OrbitLiveHomeScreen>
    with WidgetsBindingObserver {
  final OrbitMomentRepository _moments=OrbitMomentRepository();
  List<MomentData> _recent=const [];
  List<FavoritePersonData> _realFriends=const [];
  final Map<String,OrbitPerson> _friendDetails={};
  String _greeting='';
  Timer? _revalidation;
  StreamSubscription<void>? _pushEvents;
  int _reloadEpoch=0;
  final Map<String,OrbitLiveMoment> _byId={};
  final Map<String,String> _authors={};
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushEvents=OrbitMomentPushRuntime.instance.updates.listen((_){
      if(mounted)unawaited(_reload());
    });
    if(OrbitM7Rollout.enabled)unawaited(OrbitMomentPushRuntime.instance.configure());
    _revalidation=Timer.periodic(const Duration(seconds:25),(_){
      if(mounted && WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed
          && ModalRoute.of(context)?.isCurrent==true)unawaited(_reload());
    });
    unawaited(_reload());
  }

  void _clearPreviews(){
    for(final item in _recent){
      final bytes=item.encryptedImageBytes;
      if(bytes!=null)unawaited(MemoryImage(bytes).evict());
    }
    _recent=const [];
    _byId.clear();
    _authors.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused||state==AppLifecycleState.inactive
       ||state==AppLifecycleState.hidden){
      ++_reloadEpoch;
      if(mounted)setState(_clearPreviews);
    }else if(state==AppLifecycleState.resumed && mounted){
      unawaited(OrbitMomentPushRuntime.instance.configure());
      unawaited(_reload());
    }
  }

  @override
  void dispose(){
    ++_reloadEpoch;
    _revalidation?.cancel();
    unawaited(_pushEvents?.cancel());
    unawaited(OrbitMomentPushRuntime.instance.stop());
    WidgetsBinding.instance.removeObserver(this);
    _clearPreviews();
    super.dispose();
  }
  Future<void> _reload() async {
    final epoch=++_reloadEpoch;
    try {
      try {
        final person=await OrbitIdentityClient.instance.currentUser();
        final data=person['data'];
        if(data is Map && data['display_name'] is String && mounted
           && epoch==_reloadEpoch){
          setState(()=>_greeting=data['display_name'] as String);
        }
      }catch(_){}
      // M4 friends are distinct from M5 Circles. Never invent online
      // presence, favorite state or profile imagery.
      try{
        final page=await OrbitSocialRepository().friends();
        if(mounted && epoch==_reloadEpoch)setState((){
          _realFriends=page.items.take(20).map((person)=>FavoritePersonData(
            id:person.id,name:person.name,status:'Friend',
            imagePath:'',isOnline:false)).toList(growable:false);
          _friendDetails
            ..clear()
            ..addEntries(page.items.map((p)=>MapEntry(p.id,p)));
        });
      }catch(_){
        if(mounted && epoch==_reloadEpoch)setState((){
          _realFriends=const [];
          _friendDetails.clear();
        });
      }
      final rail=OrbitM7Rollout.enabled
        ? await _moments.feed(rail:true):const <OrbitLiveMoment>[];
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
      if(!mounted||epoch!=_reloadEpoch){
        for(final row in visible){
          final bytes=row.encryptedImageBytes;
          if(bytes!=null)unawaited(MemoryImage(bytes).evict());
        }
        return;
      }
      setState((){
        _clearPreviews();
        _recent=visible;
        _byId..clear()..addAll(authorized);
        _authors..clear()..addAll(authors);
      });
    } catch (_) {
      if(mounted && epoch==_reloadEpoch)setState((){
        _clearPreviews();
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

  void _demoNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Demo preview only. No plan, profile or Moment was created.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final preview = OrbitHomeDemoFixture.enabled;
    // Keep actual authorized profiles and Moments first. Distinct sample IDs
    // cannot be mistaken for backend entities or used by real API actions.
    final friends = preview
      ? <FavoritePersonData>[..._realFriends,...OrbitHomeDemoFixture.friends]
      : _realFriends;
    final recent = preview
      ? <MomentData>[
          ..._recent,
          ...OrbitHomeDemoFixture.recentMoments,
        ].take(4).toList(growable:false)
      : _recent;
    return HomeScreen(
    greetingName:_greeting,
    useLiveDate:true,
    quickActions:const <QuickActionData>[
      QuickActionData(id:'ping',title:'Ping',
        icon:Icons.bolt_rounded,
        iconColor:Color(0xFF7C3AED),iconBackground:Color(0xFFF2EAFE)),
      QuickActionData(id:'sos',title:'SOS',
        icon:Icons.sos_rounded,
        iconColor:Color(0xFFF43F8E),iconBackground:Color(0xFFFFE1EE)),
      QuickActionData(id:'explore',title:'Explore',
        icon:Icons.explore_outlined,
        iconColor:Color(0xFF4978F2),iconBackground:Color(0xFFE7EDFF)),
      QuickActionData(id:'moment',title:'Moment',
        icon:Icons.photo_camera_outlined,
        iconColor:Color(0xFF16B88B),iconBackground:Color(0xFFE2F8F2)),
    ],
    upcomingPlans:preview
      ? OrbitHomeDemoFixture.upcomingPlans
      : const <UpcomingPlanData>[],
    promoBanner:preview ? OrbitHomeDemoFixture.banner : null,
    favoritePeople:friends,
    recentMoments:recent,
    onNotificationPressed:()=>unawaited(_openNotices()),
    onQuickActionPressed:(action){
      if(action.id=='moment') {
        // Native capture is already wired through Orbit's existing launcher.
        Navigator.of(context).push<void>(MaterialPageRoute(
          builder:(_)=>OrbitLiveMomentsScreen(onTabSelected:(_){},
            onAddPressed:(){})));
      }else{
        // M7 must not pretend future Ping, SOS or Explore features are
        // operational; preserve the approved four-action Home layout.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text('${action.title} is not yet enabled. No data was shared.')));
      }
    },
    onPlanPressed:(plan){
      if(preview && OrbitHomeDemoFixture.isDemo(plan.id)) _demoNotice();
    },
    onPromoPressed:(){
      if(preview) _demoNotice();
    },
    onFavoritePersonPressed:(person){
      if(preview && OrbitHomeDemoFixture.isDemo(person.id)){
        _demoNotice();
        return;
      }
      final live=_friendDetails[person.id];
      if(live==null)return;
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder:(_)=>OrbitPersonScreen(person:live)));
    },
    onFavoriteToggle:(_){},
    onMomentPressed:(moment){
      if(preview && OrbitHomeDemoFixture.isDemo(moment.id)){
        _demoNotice();
        return;
      }
      unawaited(_view(moment));
    },
    onTabSelected:(_){},
    onAddPressed:(){},
    enableDemoCircleNavigation:false,
    );
  }
}
