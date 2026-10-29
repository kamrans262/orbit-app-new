import 'dart:async';
import 'package:flutter/material.dart';

import '../../../auth/data/orbit_identity_client.dart';
import '../../../circles/data/orbit_circle_repository.dart';
import '../../../circles/presentation/screens/orbit_live_circles_screen.dart';
import '../../../circles/presentation/screens/orbit_live_circle_detail_screen.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../../friends/presentation/screens/orbit_live_friends_screen.dart';
import '../../../friends/presentation/screens/orbit_person_screen.dart';
import '../../../moments/data/orbit_moment_repository.dart';
import '../../../ping/data/orbit_ping_repository.dart';
import '../../../ping/presentation/navigation/orbit_ping_navigation.dart';
import '../../../moments/data/orbit_m7_rollout.dart';
import '../../../moments/data/orbit_moment_push_runtime.dart';
import '../../../moments/presentation/screens/orbit_live_moment_viewer.dart';
import '../../../moments/presentation/screens/orbit_live_moments_screen.dart';
import '../../../moments/presentation/screens/orbit_live_moment_notifications_screen.dart';
import '../../data/orbit_dashboard_repository.dart';
import '../../data/orbit_m8_rollout.dart';
import '../../../presence/data/orbit_presence_rollout.dart';
import '../../../presence/presentation/orbit_presence_runtime.dart';
import '../../domain/models/home_models.dart';
import 'home_screen.dart';

/// M8 uses the approved Home presentation. No duplicate app shell, demo
/// people, fabricated location/presence, or unauthorized stored thumbnails.
class OrbitLiveHomeScreen extends StatefulWidget {
  const OrbitLiveHomeScreen({super.key,this.dashboard,this.circles,
    this.social,this.identity,this.moments});
  final OrbitDashboardRepository? dashboard;
  final OrbitCircleRepository? circles;
  final OrbitSocialRepository? social;
  final OrbitIdentityClient? identity;
  final OrbitMomentRepository? moments;
  @override
  State<OrbitLiveHomeScreen> createState()=>_OrbitLiveHomeScreenState();
}

class _OrbitLiveHomeScreenState extends State<OrbitLiveHomeScreen>
    with WidgetsBindingObserver {
  late final OrbitIdentityClient _identity=widget.identity??OrbitIdentityClient.instance;
  late final OrbitDashboardRepository _dashboard=widget.dashboard??
      OrbitDashboardRepository(identity:_identity);
  late final OrbitCircleRepository _circles=widget.circles??
      OrbitCircleRepository(identity:_identity);
  late final OrbitSocialRepository _social=widget.social??OrbitSocialRepository();
  late final OrbitMomentRepository _moments=widget.moments??
      OrbitMomentRepository(identity:_identity);
  late final OrbitPingRepository _pings=OrbitPingRepository(identity:_identity);

  List<MomentData> _recent=const [];
  List<FavoritePersonData> _people=const [];
  List<HomeCircleSummaryData> _circleCards=const [];
  final Map<String,OrbitPerson> _peopleById={};
  final Map<String,OrbitLiveMoment> _byId={};
  final Map<String,String> _authors={};
  final Set<String> _presenceCircles=<String>{};
  String _name='',_owner='';
  String? _notice;
  bool _showCircles=false,_loading=false;
  Timer? _revalidation;
  bool _refreshingPing=false;
  final Set<String> _shownPings=<String>{};
  StreamSubscription<void>? _pushEvents;
  int _epoch=0;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (OrbitPresenceRollout.enabled) {
      OrbitPresenceRuntime.instance.addListener(_presenceChanged);
    }
    _pushEvents=OrbitMomentPushRuntime.instance.updates.listen((_){
      if(mounted)unawaited(_reload());
    });
    if(OrbitM7Rollout.enabled) {
      unawaited(OrbitMomentPushRuntime.instance.configure());
    }
    _revalidation=Timer.periodic(const Duration(seconds:25),(_){
      if(mounted && !_loading &&
          WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent==true) {
        unawaited(_reload());
        unawaited(_refreshPings());
      }
    });
    unawaited(_reload());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted)unawaited(_refreshPings());
    });
  }

  Future<void> _refreshPings() async {
    if(_refreshingPing || !mounted ||
       WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed ||
       ModalRoute.of(context)?.isCurrent!=true)return;
    _refreshingPing=true;
    try {
      if(!await _pings.available())return;
      await _pings.flushPending();
      String? cursor;
      // A page may be filled entirely with already Seen Pings. Continue
      // through a bounded number of authorized pages to avoid starving
      // older unread messages and limit foreground request volume.
      for(var pageNumber=0;pageNumber<4;pageNumber++){
        final inbox=await _pings.page('inbox',cursor:cursor);
        if(!mounted || ModalRoute.of(context)?.isCurrent!=true)return;
        var displayed=false;
        for(final ping in inbox.items) {
          if(_shownPings.contains(ping.id) || ping.status=='seen')continue;
          // Do not emit a delivery receipt before the bottom sheet renders.
          _shownPings.add(ping.id);
          await OrbitPingNavigation.showIncoming(context,ping,repository:_pings);
          displayed=true;
          break;
        }
        if(displayed || inbox.nextCursor==null)break;
        cursor=inbox.nextCursor;
      }
    } catch (_) {
      // Missing backend migrations or offline service must not block Home.
    } finally {
      _refreshingPing=false;
    }
  }

  void _presenceChanged() {
    if (mounted) setState(() {});
  }

  void _syncPresenceCircles() {
    if (!OrbitPresenceRollout.enabled || !OrbitPresenceRuntime.instance.started) return;
    final wanted=_circleCards.take(8).map((c)=>c.id).toSet();
    for(final id in _presenceCircles.difference(wanted).toList()) {
      OrbitPresenceRuntime.instance.unwatch(id,source:'home');
      _presenceCircles.remove(id);
    }
    for(final id in wanted.difference(_presenceCircles)) {
      _presenceCircles.add(id);
      unawaited(OrbitPresenceRuntime.instance.watch(id,source:'home'));
    }
  }

  void _dropHomePresence() {
    if (!OrbitPresenceRollout.enabled) return;
    for (final id in _presenceCircles.toList()) {
      OrbitPresenceRuntime.instance.unwatch(id,source:'home');
    }
    _presenceCircles.clear();
  }

  List<FavoritePersonData> get _peopleWithPresence {
    if (!OrbitPresenceRollout.enabled) return _people;
    return _people.map((person) {
      final state=OrbitPresenceRuntime.instance
          .memberInCircles(_presenceCircles,person.id);
      return FavoritePersonData(id:person.id,name:person.name,
        imagePath:person.imagePath,isFavorite:person.isFavorite,
        status:state?.labelAt(DateTime.now()) ?? person.status,
        isOnline:state?.state=='active_now' ? true : null);
    }).toList(growable:false);
  }

  void _clearProtected(){
    for(final item in _recent) {
      final bytes=item.encryptedImageBytes;
      if(bytes!=null) unawaited(MemoryImage(bytes).evict());
    }
    _recent=const [];
    _people=const [];
    _circleCards=const [];
    _showCircles=false;
    _peopleById.clear();
    _byId.clear();
    _authors.clear();
    _shownPings.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused || state==AppLifecycleState.inactive ||
       state==AppLifecycleState.hidden) {
      ++_epoch;
      if(mounted)setState(_clearProtected);
    } else if(state==AppLifecycleState.resumed && mounted){
      if(OrbitM7Rollout.enabled) {
        unawaited(OrbitMomentPushRuntime.instance.configure());
      }
      unawaited(_reload());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted)unawaited(_refreshPings());
      });
    }
  }

  @override
  void dispose(){
    ++_epoch;
    _revalidation?.cancel();
    if (OrbitPresenceRollout.enabled) {
      OrbitPresenceRuntime.instance.removeListener(_presenceChanged);
      _dropHomePresence();
    }
    unawaited(_pushEvents?.cancel());
    if(OrbitM7Rollout.enabled) unawaited(OrbitMomentPushRuntime.instance.stop());
    WidgetsBinding.instance.removeObserver(this);
    _clearProtected();
    super.dispose();
  }

  bool _denied(Object e)=>e is OrbitIdentityException &&
    (e.statusCode==401 || e.statusCode==403 || e.statusCode==409);

  Future<void> _reload() async {
    if(_loading)return;
    _loading=true;
    final serial=++_epoch;
    try {
      final owner=await _identity.currentLocalSocialOwner();
      if(!mounted || serial!=_epoch)return;
      if(owner==null || owner.isEmpty){
        setState((){
          _clearProtected();
          _name='';
          _owner='';
          _notice='Sign in to refresh Home.';
        });
        return;
      }
      if(_owner!=owner){
        _dropHomePresence();
        // Account switch must purge all private in-memory cards before fetch.
        setState((){
          _clearProtected();
          _name='';
          _owner=owner;
        });
        final safe=await _identity.readDashboardSafeName();
        if(mounted && serial==_epoch && _owner==owner && safe!=null){
          setState(()=>_name=safe);
        }
      }
      OrbitDashboardSnapshot? snapshot;
      var partialUnavailable=false;
      if(OrbitM8Rollout.enabled) {
        try {
          snapshot=await _dashboard.summary();
        } on OrbitIdentityException catch(e) {
          if(_denied(e))rethrow;
          // 404 means M8 not rolled out; use each live M4/M5/M7 source,
          // not an old aggregate or untrusted local snapshot.
          if(e.statusCode!=404)partialUnavailable=true;
        }
      }
      if(!mounted||serial!=_epoch||_owner!=owner)return;
      String name='';
      try {
        if(snapshot!=null){
          name=snapshot.name;
        }else{
          final person=await _identity.currentUser();
          final v=person['data'];
          if(v is Map && v['display_name'] is String)name=v['display_name'] as String;
        }
        if(name.isNotEmpty && mounted && serial==_epoch && _owner==owner){
          setState(()=>_name=name);
          try{await _identity.storeDashboardSafeShell(owner,name);}catch(_){}
        }
      }catch(e){if(_denied(e))rethrow;}
      if(!mounted||serial!=_epoch||_owner!=owner)return;

      // An M8 summary is already viewer-filtered. On legacy rollout,
      // each M4/M5 API must still validate authorization directly.
      try{
        List<HomeCircleSummaryData> list=const [];
        bool show=false;
        if(snapshot!=null){
          final source=snapshot.circles;
          if(source.state==DashboardState.ready||source.state==DashboardState.empty){
            show=true;
            list=source.items.map((c)=>HomeCircleSummaryData(
              id:c.id,name:c.name,role:c.role,memberCount:c.memberCount,
              colorValue:c.colorValue)).toList(growable:false);
          }
        }else{
          final page=await _circles.list();
          show=true;
          list=page.items.take(8).map((c)=>HomeCircleSummaryData(
            id:c.id,name:c.name,role:c.role,memberCount:c.memberCount,
            colorValue:c.colorValue)).toList(growable:false);
        }
        if(mounted&&serial==_epoch&&_owner==owner) {
          setState(() {_showCircles=show; _circleCards=list;});
          _syncPresenceCircles();
        }
      }catch(e){
        if(_denied(e))rethrow;
        if(e is! OrbitIdentityException || e.statusCode!=404)partialUnavailable=true;
        if(mounted&&serial==_epoch) {
          setState(() {_circleCards=const []; _showCircles=false;});
          _syncPresenceCircles();
        }
      }

      try {
        final page=await _social.friends();
        final allowed=snapshot==null ? null :
          snapshot.people.items.map((p)=>p.id).toSet();
        final items=page.items.where((p)=>allowed==null||allowed.contains(p.id))
          .take(12).toList(growable:false);
        if(mounted&&serial==_epoch&&_owner==owner)setState((){
          _people=items.map((p)=>FavoritePersonData(id:p.id,name:p.name,
            status:'Friend',imagePath:'',isOnline:null)).toList(growable:false);
          _peopleById
            ..clear()
            ..addEntries(items.map((p)=>MapEntry(p.id,p)));
        });
      }catch(e){
        if(_denied(e))rethrow;
        partialUnavailable=true;
        if(mounted&&serial==_epoch)setState((){
          _people=const [];
          _peopleById.clear();
        });
      }

      final visible=<MomentData>[];
      final authorized=<String,OrbitLiveMoment>{};
      final authors=<String,String>{};
      try {
        final canRead=OrbitM7Rollout.enabled &&
          (snapshot==null || snapshot.can('moments'));
        if(canRead) {
          final allowed=snapshot==null ? null :
            {for(final m in snapshot.moments.items)m.id:m.revision};
          final rail=await _moments.feed(rail:true);
          for(final moment in rail) {
            if(visible.length>=3)break;
            if(allowed!=null && allowed[moment.id]!=moment.audienceRevision)continue;
            try {
              if(!await _moments.remainsAuthorized(moment))continue;
              // M7 photo() chooses image thumbnail, video poster or voice waveform.
              final thumbnail=await _moments.photo(moment);
              if(!await _moments.remainsAuthorized(moment)) {
                unawaited(MemoryImage(thumbnail).evict());
                continue;
              }
              final author=await _moments.name(moment.creatorId);
              final elapsed=DateTime.now().difference(moment.publishedAt);
              final time=elapsed.inMinutes<1 ? 'Just now' :
                elapsed.inHours<1 ? elapsed.inMinutes.toString()+'m ago' :
                elapsed.inHours.toString()+'h ago';
              visible.add(MomentData(id:moment.id,name:author,timeLabel:time,
                imagePath:'',encryptedImageBytes:thumbnail,
                mediaKind:moment.mediaKind));
              authorized[moment.id]=moment;
              authors[moment.id]=author;
            }catch(_){
              // A revoked/deleted Moment is absent, never replaced by a demo tile.
            }
          }
        }
      }catch(e){
        if(_denied(e))rethrow;
        partialUnavailable=true;
      }
      if(!mounted||serial!=_epoch||_owner!=owner){
        for(final data in visible){
          final bytes=data.encryptedImageBytes;
          if(bytes!=null)unawaited(MemoryImage(bytes).evict());
        }
        return;
      }
      setState((){
        for(final item in _recent) {
          final bytes=item.encryptedImageBytes;
          if(bytes!=null)unawaited(MemoryImage(bytes).evict());
        }
        _recent=visible;
        _byId..clear()..addAll(authorized);
        _authors..clear()..addAll(authors);
        _notice=partialUnavailable
          ? 'Some Home sections could not be verified. Retry.' : null;
      });
    }catch(e){
      if(mounted && serial==_epoch) {
        setState((){
          _clearProtected();
          _notice=_denied(e) ?
            'Home access must be verified. Please sign in or retry.' :
            'Unable to verify Home. Reconnect and retry.';
          if(_denied(e)){_owner='';_name='';}
        });
        if(_denied(e)){
          _dropHomePresence();
          try{await _identity.clearDashboardSafeShell();}catch(_){}
        }
      }
    }finally{_loading=false;}
  }

  Future<void> _view(MomentData data) async {
    final moment=_byId[data.id];
    if(moment==null||!mounted)return;
    try{
      if(!await _moments.remainsAuthorized(moment)){
        if(mounted)unawaited(_reload());
        return;
      }
    }catch(_){if(mounted)unawaited(_reload());return;}
    if(!mounted)return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(moment:moment,
        repository:_moments,author:_authors[data.id]??'Orbit member')));
    if(mounted)unawaited(_reload());
  }

  void _openMoments(){
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentsScreen(onTabSelected:(_){},onAddPressed:(){})));
  }

  void _unavailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(feature+' is not available yet. No data was shared.')));
  }

  @override
  Widget build(BuildContext context)=>HomeScreen(
    greetingName:_name,useLiveDate:true,
    dashboardNotice:_notice,
    onDashboardRetry:()=>unawaited(_reload()),
    showCircleSection:_showCircles,circleSummaries:_circleCards,
    onCirclePressed:(c) => Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveCircleDetailScreen(circleId:c.id))),
    onSeeAllCirclesPressed:()=>Navigator.of(context).push<void>(
      MaterialPageRoute(builder:(_)=>const OrbitLiveCirclesScreen())),
    peopleSectionTitle:'Friends',planUnavailable:true,
    quickActions:const <QuickActionData>[
      QuickActionData(id:'ping',title:'Ping',icon:Icons.bolt_rounded,
        iconColor:Color(0xFF7C3AED),iconBackground:Color(0xFFF2EAFE)),
      QuickActionData(id:'sos',title:'SOS',icon:Icons.sos_rounded,
        iconColor:Color(0xFFF43F8E),iconBackground:Color(0xFFFFE1EE)),
      QuickActionData(id:'explore',title:'Explore',icon:Icons.explore_outlined,
        iconColor:Color(0xFF4978F2),iconBackground:Color(0xFFE7EDFF)),
      QuickActionData(id:'moment',title:'Moment',icon:Icons.photo_camera_outlined,
        iconColor:Color(0xFF16B88B),iconBackground:Color(0xFFE2F8F2)),
    ],
    upcomingPlans:const <UpcomingPlanData>[],promoBanner:null,
    favoritePeople:_peopleWithPresence,recentMoments:_recent,
    onNotificationPressed:(){
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder:(_)=>const OrbitLiveMomentNotificationsScreen()));
    },
    onQuickActionPressed:(action){
      if(action.id=='moment'){_openMoments();}
      else if(action.id=='ping'){
        unawaited(OrbitPingNavigation.chooseFriend(context,
          social:_social,repository:_pings));
      }else {_unavailable(action.title);}
    },
    onPlanPressed:(_){},onPromoPressed:(){},
    onSeeAllFriendsPressed:()=>Navigator.of(context).push<void>(
      MaterialPageRoute(builder:(_)=>const OrbitLiveFriendsScreen())),
    onSeeAllMomentsPressed:_openMoments,
    onFavoritePersonPressed:(person){
      final live=_peopleById[person.id];
      if(live!=null)Navigator.of(context).push<void>(
        MaterialPageRoute(builder:(_)=>OrbitPersonScreen(person:live)));
    },
    onFavoriteToggle:(_){},
    onMomentPressed:(m)=>unawaited(_view(m)),
    onTabSelected:(_){},onAddPressed:(){},
    enableDemoCircleNavigation:false,
  );
}
