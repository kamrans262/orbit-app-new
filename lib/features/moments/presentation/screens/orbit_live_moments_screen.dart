import '../../../realtime/data/orbit_realtime_contract.dart';
import '../../../realtime/presentation/orbit_realtime_refresh.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/navigation/orbit_moment_link.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';

import '../../data/orbit_moment_repository.dart';
import '../../../activity/data/orbit_activity_repository.dart';
import '../../../advertising/data/orbit_advertising_repository.dart';
import '../../../check_in/data/orbit_check_in_repository.dart';
import '../../../check_in/presentation/navigation/orbit_check_in_navigation.dart';
import '../../data/orbit_m7_rollout.dart';
import '../../data/orbit_moment_offline_cache.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../domain/models/moments_models.dart';
import '../screens/moment_camera_screen.dart';
import '../screens/moments_screen.dart';
import '../screens/orbit_live_moment_viewer.dart';

/// The authenticated replacement for MomentsScreen.demo. It passes real
/// server-authorized data to the existing styled MomentsScreen only.
class OrbitLiveMomentsScreen extends StatefulWidget {
  const OrbitLiveMomentsScreen({required this.onTabSelected,this.onAddPressed,
    this.circleId,this.profileId,this.activity,this.advertising,super.key});
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onAddPressed;
  final String? circleId, profileId;
  final OrbitActivityRepository? activity;
  final OrbitAdvertisingRepository? advertising;
  @override
  State<OrbitLiveMomentsScreen> createState()=>_OrbitLiveMomentsScreenState();
}
class _OrbitLiveMomentsScreenState extends State<OrbitLiveMomentsScreen> with WidgetsBindingObserver {
  final OrbitMomentRepository _repo=OrbitMomentRepository();
  late final OrbitActivityRepository _activity=widget.activity??
      OrbitActivityRepository();
  final OrbitCheckInRepository _checkIns=OrbitCheckInRepository();
  late final OrbitAdvertisingRepository _advertising=widget.advertising??
      OrbitAdvertisingRepository();
  OrbitSponsoredDecision? _sponsored;
  bool _sponsorImpressionAccepted=false;
  bool _sponsorLoading=false;
  int _sponsorEpoch=0;
  Timer? _sponsorExpiry;
  bool _sponsorMeasuring=false;
  List<({String activityId,OrbitCheckInRecord record,DateTime at})>
      _activityCheckIns=const [];
  final OrbitMomentOfflineCache _offline=OrbitMomentOfflineCache();
  List<OrbitLiveMoment> _items=const [];
  List<OrbitLiveMoment> _rail=const [];
  final Map<String,Uint8List> _previews={};
  final Map<String,String> _names={};
  final Map<String,String> _captions={};
  final Map<String,String> _places={};
  final Set<String> _likes={};
  final Set<String> _bookmarked={};
  final Set<String> _seen={};
  bool _busy=true;
  String? _loadedOwner;
  bool _initialLoadComplete=false;
  bool _autoRetryInFlight=false;
  bool _backgroundCleared=false;
  bool _viewerOpening=false;
  DateTime? _lastSuccessfulLoad;
  DateTime? _retryNotBefore;
  final Map<String,DateTime> _cacheLeaseAt={};
  bool _showingOfflinePreviews=false;
  String? _error;
  int _pendingPublishCount=0;
  String? _pendingWarning;
  bool _retrying=false;
  bool _publishingNow=false;
  bool _loadingMore=false;
  bool _hasMore=false;
  int _feedLimit=30;
  bool _feedRequestInFlight=false;
  bool _feedRefreshQueued=false;
  Timer? _authorizationRefresh;
  int _loadEpoch=0;

  OrbitRealtimeRefresh? _m25Refresh;
  @override
  void initState(){
    super.initState();
    _m25Refresh=OrbitRealtimeRefresh(modules:const {'moments','activity','check_in','social','circles'},visible:()=>OrbitRealtimeRefresh.current(this),refresh:()=>_load(background:true),fallback:false,
      minimumInterval:const Duration(seconds:10))..start();

    WidgetsBinding.instance.addObserver(this);
    _authorizationRefresh=Timer.periodic(const Duration(seconds:25),(_){
      if(!mounted || _busy ||
          WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed ||
          ModalRoute.of(context)?.isCurrent!=true||_viewerOpening)return;
      if(OrbitRealtimeRollout.selected){_m25Refresh?.poll();}else{
      unawaited(_load(background:true));
      }
    });
    unawaited(_load(retryDrafts:true));
  }

  void _evictDecodedMedia() {
    for(final bytes in _previews.values) {
      unawaited(MemoryImage(bytes).evict());
    }
    _previews.clear();
    _captions.clear();
    _places.clear();
    _cacheLeaseAt.clear();
  }

  void _clearSponsored(){
    _sponsorExpiry?.cancel();_sponsorExpiry=null;
    _sponsorMeasuring=false;
    ++_sponsorEpoch;
    _sponsorLoading=false;
    final item=_sponsored;
    if(item!=null)unawaited(MemoryImage(item.imageBytes).evict());
    _sponsored=null;
    _sponsorImpressionAccepted=false;
  }

  void _expireSponsored(OrbitSponsoredDecision? value){
    _sponsorExpiry?.cancel();
    if(value==null)return;
    final remaining=value.expiresAt.difference(DateTime.now().toUtc());
    _sponsorExpiry=Timer(remaining.isNegative?Duration.zero:remaining,(){
      if(!mounted||!value.sameAuthorization(_sponsored))return;
      setState((){
        _sponsored=null;_sponsorImpressionAccepted=false;
        _sponsorMeasuring=false;
      });
      unawaited(MemoryImage(value.imageBytes).evict());
    });
  }

  Future<void> _refreshSponsored() async {
    if(!mounted||_sponsorLoading||_busy||_showingOfflinePreviews||
       widget.circleId!=null||widget.profileId!=null||
       WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed ||
       ModalRoute.of(context)?.isCurrent!=true)return;
    _sponsorLoading=true;
    final serial=++_sponsorEpoch;
    final previous=_sponsored;
    // Keep a verified card stable while refreshing its server authorization.
    OrbitSponsoredDecision? next;
    try{
      next=await _advertising.load(OrbitAdvertisingRepository.momentsPlacement,
        previous:previous);
      final current=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(!mounted||serial!=_sponsorEpoch||_showingOfflinePreviews||
         widget.circleId!=null||widget.profileId!=null||
         (next!=null&&next.owner!=current)||
         WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed||
         ModalRoute.of(context)?.isCurrent!=true){
        if(next!=null&&!identical(next.imageBytes,previous?.imageBytes))
          unawaited(MemoryImage(next.imageBytes).evict());
        return;
      }
      setState((){
        if(next==null||!next.sameAuthorization(previous)){
          _sponsorImpressionAccepted=false;_sponsorMeasuring=false;
        }
        _sponsored=next;
      });
      _expireSponsored(next);
    }catch(_){
      if(mounted&&serial==_sponsorEpoch){
        setState((){
          _sponsorExpiry?.cancel();_sponsorExpiry=null;
          _sponsored=null;
          _sponsorMeasuring=false;
          _sponsorImpressionAccepted=false;
        });
      }
    }finally{
      if(previous!=null&&!identical(previous.imageBytes,next?.imageBytes)){
        unawaited(MemoryImage(previous.imageBytes).evict());
      }
      if(serial==_sponsorEpoch)_sponsorLoading=false;
    }
  }

  bool _sponsorCurrent(OrbitSponsoredDecision value)=>mounted &&
    value.sameAuthorization(_sponsored) && !value.expired &&
    WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed &&
    ModalRoute.of(context)?.isCurrent==true && !_showingOfflinePreviews && widget.circleId==null && widget.profileId==null;

  Future<void> _sponsorVisible(int milliseconds) async {
    final value=_sponsored;
    if(value==null||_sponsorImpressionAccepted||_sponsorMeasuring||!_sponsorCurrent(value))return;
    _sponsorMeasuring=true;
    try{
      final accepted=await _advertising.impression(value,milliseconds);
      if(_sponsorCurrent(value)&&accepted)_sponsorImpressionAccepted=true;
    }catch(_){
      // Never fabricate a measurement after a denial.
    }finally{
      if(value.sameAuthorization(_sponsored))_sponsorMeasuring=false;
    }
  }

  Future<void> _openSponsored() async {
    final value=_sponsored;
    if(value==null||!_sponsorImpressionAccepted||!_sponsorCurrent(value))return;
    try{
      final accepted=await _advertising.click(value);
      final current=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(!accepted||current!=value.owner||!_sponsorCurrent(value))return;
      await launchUrl(value.destination,mode:LaunchMode.externalApplication);
    }catch(_){
      // Revoked or unavailable advertiser destinations never open.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.paused || state==AppLifecycleState.hidden) {
      if(_backgroundCleared)return;
      _backgroundCleared=true;
      ++_loadEpoch;
      if(mounted)setState((){
        _evictDecodedMedia();
        _items=const [];
        _rail=const [];
        _activityCheckIns=const [];
        _clearSponsored();
        _names.clear();
        _likes.clear();
        _bookmarked.clear();
        _seen.clear();
        _busy=true;
        _initialLoadComplete=false;
        _lastSuccessfulLoad=null;
      });
    }else if(state==AppLifecycleState.resumed && _backgroundCleared) {
      _backgroundCleared=false;
      if(mounted&&ModalRoute.of(context)?.isCurrent==true)unawaited(_load());
    }
  }

  @override
  void dispose() {
    _m25Refresh?.dispose();

    ++_loadEpoch;
    _authorizationRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _evictDecodedMedia();
    _activityCheckIns=const [];
    _clearSponsored();
    super.dispose();
  }

  Future<bool> _showValidOfflinePreviews(int epoch) async {
    try{
      final previews=await _offline.read();
      if(previews.isEmpty || !mounted || epoch!=_loadEpoch)return false;
      final items=<OrbitLiveMoment>[];
      final bytes=<String,Uint8List>{};
      final labels=<String,String>{};
      for(final preview in previews){
        items.add(OrbitLiveMoment(
          id:preview.id,creatorId:preview.creatorId,
          mediaId:preview.mediaId,contextId:preview.contextId,
          publishedAt:preview.publishedAt));
        bytes[preview.id]=preview.bytes;
        labels[preview.creatorId]='Offline preview';
      }
      setState((){
        _evictDecodedMedia();
        _items=items;
        _rail=items.where((m)=>DateTime.now().toUtc()
          .isBefore(m.publishedAt.add(const Duration(hours:24)))).toList();
        _previews..clear()..addAll(bytes);
        _names..clear()..addAll(labels);
        _likes.clear();_bookmarked.clear();_seen.clear();
        _captions.clear();_places.clear();
        _clearSponsored();
        _showingOfflinePreviews=true;
        _hasMore=false;
        _error=null;
        _busy=false;
      });
      return true;
    }catch(_){return false;}
  }

  Future<void> _load({bool incremental=false,bool retryDrafts=false,bool background=false}) async {
    if(!mounted)return;
    if(background){
      if(_viewerOpening||_backgroundCleared||ModalRoute.of(context)?.isCurrent!=true)return;
      final retryAt=_retryNotBefore;
      if(retryAt!=null&&DateTime.now().isBefore(retryAt))return;
      final last=_lastSuccessfulLoad;
      if(last!=null&&DateTime.now().difference(last)<const Duration(seconds:10))return;
    }
    if(_feedRequestInFlight){if(!background)_feedRefreshQueued=true;return;}
    if(!OrbitM7Rollout.enabled){
      ++_loadEpoch;
      setState((){
        _evictDecodedMedia();
        _items=const [];
        _rail=const [];
        _activityCheckIns=const [];
        _clearSponsored();
        _names.clear();
        _likes.clear();
        _bookmarked.clear();
        _seen.clear();
        _showingOfflinePreviews=false;
        _hasMore=false;
        _pendingPublishCount=0;
        _pendingWarning=null;
        _error='Moments unavailable.';
        _busy=false;
      });
      return;
    }
    _feedRequestInFlight=true;
    final epoch=++_loadEpoch;
    if(!background&&!_initialLoadComplete){
      setState((){_busy=true;_error=null;});
    }
    try {
      // Resume only this account's encrypted outbox while foregrounded.
      // Failures leave the original ciphertext queued without fake success.

      final owner=await _repo.currentUserId();
      if(owner==null)throw OrbitIdentityException('Sign in to view Moments.',401);
      if(!mounted||epoch!=_loadEpoch)return;
      if(_loadedOwner!=null&&_loadedOwner!=owner){
        setState((){_evictDecodedMedia();_items=const [];_rail=const [];
          _activityCheckIns=const [];_names.clear();_seen.clear();_clearSponsored();_busy=true;});
      }
      _loadedOwner=owner;
      String? pendingProblem;
      var waiting=0;
      try{waiting=await _repo.pendingPublishCount();}catch(_){}
      if(waiting>0){
        try{pendingProblem=await _repo.pendingDraftNotice();}catch(_){}
      }
      if(mounted && epoch==_loadEpoch &&
          (waiting!=_pendingPublishCount||pendingProblem!=_pendingWarning))setState((){
        _pendingPublishCount=waiting;
        _pendingWarning=pendingProblem;
      });
      // Fetch one extra item to expose real authenticated cursor continuation.
      final page=await _repo.feed(maxItems:_feedLimit+1,
        circleId:widget.circleId,profileId:widget.profileId);
      final hasMore=page.length>_feedLimit;
      final moments=page.take(_feedLimit).toList(growable:false);
      final rail=widget.circleId!=null||widget.profileId!=null
        ? moments.where((m)=>DateTime.now().difference(m.publishedAt)
          <const Duration(hours:24)).take(20).toList(growable:false)
        : await _repo.feed(rail:true,maxItems:20);
      final seen=await _repo.seenMomentIds(rail.map((m)=>m.id));
      Set<String> saved=<String>{};
      try{saved=await _repo.bookmarkedMomentIds(moments);}catch(_){
        // Corrupt local bookmark metadata must not block the authorized feed.
      }
      final names=<String,String>{};
      final previews=<String,Uint8List>{};
      final captions=<String,String>{};
      final places=<String,String>{};
      final unique=<String>{};
      final prefetch=<OrbitLiveMoment>[
        for(final m in [...rail,...moments])
          if(unique.add(m.id))m,
      ];
      // A fresh server feed is authoritative. Keep decrypted bytes only
      // when the same account, media, context and audience revision match.
      final previous={for(final m in [..._rail,..._items])m.id:m};
      final stable=<String>{};
      for(final m in prefetch){
        final prior=previous[m.id];
        if(!_showingOfflinePreviews&&prior!=null&&prior.mediaId==m.mediaId&&
           prior.contextId==m.contextId&&prior.audienceRevision==m.audienceRevision&&
           prior.publishVersion==m.publishVersion)stable.add(m.id);
      }
      if(await _repo.currentUserId()!=owner)throw OrbitIdentityException('Moment account changed.',401);
      if(!mounted||epoch!=_loadEpoch)return;
      List<({String activityId,OrbitCheckInRecord record,DateTime at})>
          activityCheckIns=const [];
      try {
        activityCheckIns=await _loadActivityCheckIns();
      }on OrbitIdentityException catch(e){
        if(e.statusCode==401||e.statusCode==403||e.statusCode==409)rethrow;
        // An unapplied M18 backend must not break the existing M7 feed.
      }catch(_){
        // Never show a previous M18 Activity cache after a failed refresh.
      }
      if(!mounted||epoch!=_loadEpoch)return;
      bool sameList(List<OrbitLiveMoment> previous,List<OrbitLiveMoment> next)=>
        previous.length==next.length&&List.generate(next.length,(i)=>i).every((i)=>
          previous[i].id==next[i].id&&previous[i].contextId==next[i].contextId&&
          previous[i].mediaId==next[i].mediaId&&
          previous[i].audienceRevision==next[i].audienceRevision&&
          previous[i].publishVersion==next[i].publishVersion&&
          previous[i].myReaction==next[i].myReaction);
      final sameCheckIns=_activityCheckIns.length==activityCheckIns.length&&
        List.generate(activityCheckIns.length,(i)=>i).every((i)=>
          _activityCheckIns[i].activityId==activityCheckIns[i].activityId&&
          _activityCheckIns[i].record.label==activityCheckIns[i].record.label&&
          _activityCheckIns[i].record.creatorName==activityCheckIns[i].record.creatorName);
      // Do not rebuild unchanged, freshly authorized feed content.
      if(background&&_initialLoadComplete&&!_showingOfflinePreviews&&_error==null&&
         sameList(_items,moments)&&sameList(_rail,rail)&&sameCheckIns&&
         prefetch.every((m)=>stable.contains(m.id)&&_previews.containsKey(m.id))&&
         _seen.length==seen.length&&_seen.containsAll(seen)&&
         _bookmarked.length==saved.length&&_bookmarked.containsAll(saved)){
        _lastSuccessfulLoad=DateTime.now();_retryNotBefore=null;
        return;
      }
      // Immediately remove revoked/expired entries while new media loads.
      setState((){
        _items=moments;_rail=rail;
        for(final id in _previews.keys.toList()){
          if(!stable.contains(id)){
            final bytes=_previews.remove(id);
            if(bytes!=null)unawaited(MemoryImage(bytes).evict());
          }
        }
        _captions.removeWhere((id,_)=>!stable.contains(id));
        _places.removeWhere((id,_)=>!stable.contains(id));
        _cacheLeaseAt.removeWhere((id,_)=>!stable.contains(id));
        _activityCheckIns=activityCheckIns;
      });
      final retained=Set<Uint8List>.identity()..addAll(_previews.values);
      previews.addAll(_previews);
      captions.addAll(_captions);places.addAll(_places);
      for(final m in prefetch){
        final name=_names[m.creatorId];
        if(name!=null&&!_showingOfflinePreviews)names[m.creatorId]=name;
      }
      // Next-two bounded prefetch: three authorized thumbnail/decrypt requests
      // at most. Avoid serial head-of-line latency and unbounded media memory.
      for(var index=0;index<prefetch.length;index+=3){
        final batch=prefetch.skip(index).take(3);
        await Future.wait(batch.map((m) async {
          try {
            names[m.creatorId]??=await _repo.name(m.creatorId);
          }catch(_){names[m.creatorId]??='Orbit member';}
          try {
            if(stable.contains(m.id)&&previews.containsKey(m.id))return;
            previews[m.id]=await _repo.photo(m);
            final text=await _repo.caption(m);
            if(text!=null)captions[m.id]=text;
            final place=await _repo.place(m);
            if(place!=null)places[m.id]=place;
          }catch(_){
            // An expired or revoked key never uses a public-media fallback.
          }
        }));
        if(!mounted || epoch!=_loadEpoch)break;
      }
      if(!mounted || epoch!=_loadEpoch){
        for(final bytes in previews.values){if(!retained.contains(bytes))unawaited(MemoryImage(bytes).evict());}
        return;
      }
      // A new authenticated feed is authoritative: evict any stale audience
      // entries before issuing new short server-bound encrypted preview leases.
      try {
        await _offline.reconcile(moments
          .map((m)=>'${m.id}|${m.contextId}|${m.audienceRevision}').toSet());
        for(final m in prefetch.take(3)){
          if(!mounted || epoch!=_loadEpoch)break;
          final lastLease=_cacheLeaseAt[m.id];
          if(lastLease!=null&&DateTime.now().difference(lastLease)<const Duration(minutes:3))continue;
          final preview=previews[m.id];
          if(preview==null || preview.length>OrbitMomentOfflineCache.maxPreviewBytes)continue;
          try {
            final lease=await _repo.offlinePreviewLease(m);
            if(!mounted || epoch!=_loadEpoch)break;
            await _offline.save(
              id:m.id,mediaId:m.mediaId,creatorId:m.creatorId,
              contextId:m.contextId,audienceRevision:m.audienceRevision,
              publishedAt:m.publishedAt,
              issuedAt:lease.issued,expiresAt:lease.expires,
              viewExpiresAt:lease.viewExpires,preview:preview);
            if(mounted&&epoch==_loadEpoch)_cacheLeaseAt[m.id]=DateTime.now();
          }catch(_){
            // Failure to obtain current server lease disables offline reuse.
          }
        }
      }catch(_){}
      if(!mounted || epoch!=_loadEpoch)return;
      if(await _repo.currentUserId()!=owner)throw OrbitIdentityException('Moment account changed.',401);
      if(!mounted||epoch!=_loadEpoch)return;
      setState((){
        _showingOfflinePreviews=false;
        _initialLoadComplete=true;
        _lastSuccessfulLoad=DateTime.now();_retryNotBefore=null;
        _error=null;
        _items=moments;_rail=rail;
        _activityCheckIns=activityCheckIns;
        _hasMore=hasMore && _feedLimit<240;
        _likes..clear()..addAll(moments.where((item)=>item.myReaction=='like').map((item)=>item.id));
        _bookmarked..clear()..addAll(saved);
        _previews..clear()..addAll(previews);
        _names..clear()..addAll(names);
        _seen..clear()..addAll(seen);
        _captions..clear()..addAll(captions);
        _places..clear()..addAll(places);
        _busy=false;
      });
      // A missing/disabled M20 backend never blocks or redesigns M7 Moments.
      unawaited(_refreshSponsored());
      if(retryDrafts&&waiting>0)unawaited(_resumeDraftsOnce());
    }on OrbitIdentityException catch(error){
      if(error.statusCode==429)_retryNotBefore=DateTime.now().add(error.retryAfter??const Duration(minutes:1));
      if(error.statusCode==null || (error.statusCode!=null &&
          error.statusCode!>=500)){
        if(await _showValidOfflinePreviews(epoch))return;
      }else{
        // A server authorization denial is never an offline-cache fallback.
        try{
          final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
          if(owner!=null)await _offline.purge(owner);
        }catch(_){}
      }
      if(mounted && epoch==_loadEpoch)setState((){
        _evictDecodedMedia();
        _items=const [];_rail=const [];
        _activityCheckIns=const [];
        _clearSponsored();
        _names.clear();_likes.clear();_bookmarked.clear();
        _showingOfflinePreviews=false;_busy=false;_initialLoadComplete=true;
        _error='Unable to verify private Moments. Check your connection.';
      });
    }catch(_){
      if(mounted && epoch==_loadEpoch)setState((){
        _evictDecodedMedia();
        _items=const [];
        _rail=const [];
        _clearSponsored();
        _names.clear();
        _likes.clear();
        _busy=false;_initialLoadComplete=true;
        _error='Unable to load encrypted Moments. Check your connection and try again.';
      });
    }finally{
      _feedRequestInFlight=false;
      if(_feedRefreshQueued){
        _feedRefreshQueued=false;
        if(mounted&&WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed&&!_viewerOpening&&ModalRoute.of(context)?.isCurrent==true)unawaited(_load());
      }
    }
  }
  Future<void> _loadMore() async {
    if(!mounted || _busy || _loadingMore || !_hasMore ||
       _showingOfflinePreviews || !OrbitM7Rollout.enabled)return;
    setState((){
      _loadingMore=true;
      _feedLimit=(_feedLimit+30).clamp(30,240);
    });
    try{
      await _load(incremental:true);
    }finally{
      if(mounted)setState(()=>_loadingMore=false);
    }
  }

  Future<void> _resumeDraftsOnce() async{
    if(!mounted||_autoRetryInFlight||_retrying||_publishingNow)return;
    _autoRetryInFlight=true;
    try{
      final completed=await _repo.resumePendingPublishes();
      if(mounted&&completed>0)unawaited(_load());
    }catch(_){
      if(mounted)setState(()=>_pendingWarning='Waiting for connection or a secure retry');
    }finally{_autoRetryInFlight=false;}
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
  List<OrbitLiveMoment> _storyGroups(){
    final groups=<String,List<OrbitLiveMoment>>{};
    final newest=<String,DateTime>{};
    for(final m in _rail){
      groups.putIfAbsent('${m.contextId}|${m.creatorId}',()=>[]).add(m);
      if(newest[m.contextId]==null||m.publishedAt.isAfter(newest[m.contextId]!)){
        newest[m.contextId]=m.publishedAt;
      }
    }
    final entries=groups.values.toList()..sort((a,b){
      final byContext=newest[b.first.contextId]!.compareTo(newest[a.first.contextId]!);
      if(byContext!=0)return byContext;
      final byCircle=a.first.contextId.compareTo(b.first.contextId);
      if(byCircle!=0)return byCircle;
      return b.first.publishedAt.compareTo(a.first.publishedAt);
    });
    return [for(final group in entries) ...group.reversed];
  }

  Future<void> _openViewer(OrbitLiveMoment item,
      {bool storyGroup=false,bool comments=false}) async {
    if(!mounted||_viewerOpening)return;
    if(_showingOfflinePreviews){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text(
          'Offline previews are read-only. Reconnect to verify this Moment.')));
      return;
    }
    final playlist=storyGroup?_storyGroups():<OrbitLiveMoment>[];
    final start=storyGroup?playlist.indexWhere((m)=>
      m.creatorId==item.creatorId&&m.contextId==item.contextId&&!_seen.contains(m.id)):-1;
    final first=start>=0?start:playlist.indexWhere((m)=>
      m.creatorId==item.creatorId&&m.contextId==item.contextId);
    _viewerOpening=true;
    try{await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveMomentViewer(moment:item,repository:_repo,
        author:_names[item.creatorId]??'Orbit member',
        authorNames:Map<String,String>.from(_names),
        playlist:playlist,initialIndex:first<0?0:first,
        openComments:comments,onViewed:(id){
          if(mounted)setState(()=>_seen.add(id));
        })));}finally{_viewerOpening=false;}
    // Viewer actions may have changed the feed; only reconcile authorized
    // metadata, retaining already decoded, unchanged media and scroll state.
    if(mounted)unawaited(_load(background:true));
  }
  void _openById(String id,{bool storyGroup=false,bool comments=false}){
    for(final moment in [..._rail,..._items]){
      if(moment.id==id){
        unawaited(_openViewer(moment,storyGroup:storyGroup,comments:comments));return;
      }
    }
  }
  Future<void> _react(MomentImageFeedItem item,bool liked) async {
    if(_showingOfflinePreviews)return;
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
  Future<void> _shareAuthorizedMoment(MomentImageFeedItem item) async {
    if(_showingOfflinePreviews)return;
    OrbitLiveMoment? selected;
    for(final m in _items)if(m.id==item.id){selected=m;break;}
    if(selected==null)return;
    try{
      // Sharing this reference never shares ciphertext, keys or privileges.
      // The receiving installation must authenticate and pass current ACLs.
      final current=await _repo.authorizedMoment(selected.id);
      if(!mounted || current.id!=selected.id)return;
      await Share.share('View this private Moment in Orbit if you have access:\n'+
        OrbitMomentLink.create(current.id).toString());
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('This private Moment is no longer shareable.')));
    }
  }

  Future<void> _setBookmark(MomentImageFeedItem item,bool saved) async {
    if(_showingOfflinePreviews)return;
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
    audienceLoader:() {
      if(!OrbitM7Rollout.enabled)throw StateError('Moments unavailable.');
      return _repo.audienceOptions();
    },
    publishMoment:OrbitM7Rollout.enabled ? (request,progress) async {
      if(mounted)setState((){
        _publishingNow=true;
      });
      try{
        final receipt=await _repo.publish(request,progress);
        if(mounted)unawaited(_load());
        return receipt;
      }finally{
        if(mounted)setState(()=>_publishingNow=false);
      }
    } : null,
  );

  /// The unconfirmed item belongs in the local feed, not a fabricated
  /// backend Moment. It has no like/comment/share actions or fake receipt.
  Widget? _pendingCard(){
    if(_publishingNow || _pendingPublishCount==0)return null;
    final label='Moment draft waiting to send';
    return Material(
      color:AppColors.background,
      elevation:2,
      borderRadius:BorderRadius.circular(20),
      child:Padding(padding:const EdgeInsets.all(12),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Row(children:[
            const Icon(Icons.lock_outline_rounded,
              color:AppColors.primaryEnd,size:22),
            const SizedBox(width:8),
            Expanded(child:Text(label,style:AppTypography.body)),
          ]),
          const SizedBox(height:8),
          if(!_publishingNow &&
             ((_pendingWarning??'').startsWith('Draft needs review') ||
              (_pendingWarning??'').startsWith('Encrypted draft is incomplete')))
            AppPrimaryButton(label:'Discard unrecoverable draft',
              enabled:!_retrying,
              onPressed:()=>unawaited(_discardUnrecoverable()))
          else if(!_publishingNow && _pendingPublishCount>0)
            AppPrimaryButton(
              label:_retrying?'Sending…':'Retry encrypted draft',
              enabled:!_retrying,
              onPressed:()=>unawaited(_retryEncryptedDrafts())),
        ]),
      ),
    );
  }
  Future<List<({String activityId,OrbitCheckInRecord record,DateTime at})>>
      _loadActivityCheckIns() async {
    // Never mix Circle- or profile-specific Moments with a global feed.
    if(widget.circleId!=null||widget.profileId!=null)return const [];
    final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
    if(owner==null||owner.isEmpty)return const [];
    final capabilities=await _activity.capabilities();
    if(!capabilities.available || !capabilities.checkIns)return const [];
    // Backend changes endpoint explicitly instructs authoritative refresh.
    await _activity.requiresRefresh();
    final pointers=await _activity.currentPointers(
      maximum:(_feedLimit+1).clamp(1,240));
    final selected=<OrbitActivityItem>[],seen=<String>{};
    for(final pointer in pointers) {
      if(pointer.sourceType!='check_in'||!seen.add(pointer.sourceId))continue;
      selected.add(pointer);
      if(selected.length>=24)break; // Bounded requests and private memory.
    }
    final resolved=<({String activityId,OrbitCheckInRecord record,DateTime at})>[];
    for(var offset=0;offset<selected.length;offset+=3) {
      final batch=selected.skip(offset).take(3);
      final fetched=await Future.wait(batch.map((entry) async {
        try {
          // M12 enforces the current audience version and block relationship.
          final detail=await _checkIns.detail(entry.sourceId);
          if(detail.id!=entry.sourceId)return null;
          return (activityId:entry.id,record:detail,at:entry.occurredAt);
        }on OrbitIdentityException catch(e){
          if(e.statusCode==401||e.statusCode==403||e.statusCode==409)rethrow;
          return null;
        }catch(_){return null;}
      }));
      resolved.addAll(fetched.whereType<
        ({String activityId,OrbitCheckInRecord record,DateTime at})>());
    }
    if(owner!=await OrbitIdentityClient.instance.currentLocalSocialOwner()){
      throw OrbitIdentityException('Activity owner changed.',409);
    }
    return List<({String activityId,OrbitCheckInRecord record,DateTime at})>
      .unmodifiable(resolved);
  }

  Future<void> _openActivityCheckIn(String cardId) async {
    if(!mounted || !cardId.startsWith('activity-check-in:'))return;
    try {
      final pointer=await _activity.item(
        cardId.substring('activity-check-in:'.length));
      if(pointer.sourceType!='check_in' || !mounted)return;
      await OrbitCheckInNavigation.openDetail(context,pointer.sourceId,
        repository:_checkIns);
    }catch(_){
      // No local preview or fake sheet after source revocation.
    }finally{
      if(mounted)unawaited(_load());
    }
  }

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
        imageBytes:_previews[m.id],ageLabel:_relative(m.publishedAt),
        isCircle:m.contextId.startsWith('circle:'),
        isUnseen:groupUnseen[m.contextId+'|'+m.creatorId]??false),
    ];
    final momentCards=<MomentFeedItem>[
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
    // Render M18 authorized Check-Ins with an already approved text card.
    // The M7 image stream remains authoritative and is never hidden when
    // the M18 projector is late, disabled, or not yet deployed.
    final ordered=<({DateTime at,MomentFeedItem card})>[
      for(var i=0;i<_items.length;i++)
        (at:_items[i].publishedAt,card:momentCards[i]),
      if(!_showingOfflinePreviews)
        for(final entry in _activityCheckIns)
          (at:entry.at,card:MomentTextFeedItem(
            id:'activity-check-in:'+entry.activityId,
            author:MomentAuthorData(id:entry.record.creatorId,
              name:entry.record.creatorName),
            timeLabel:_relative(entry.at),
            text:'Check-In · '+entry.record.label,isCheckIn:true)),
    ]..sort((a,b)=>b.at.compareTo(a.at));
    final feed=<MomentFeedItem>[for(final entry in ordered)entry.card];
    // M20 uses the already approved Moments promo card; no new placement in
    // Circle/profile/private/offline/notifications/messaging/SOS screens.
    final ad=_sponsored;
    if(ad!=null&&!ad.expired&&!_showingOfflinePreviews&&
       widget.circleId==null&&widget.profileId==null){
      feed.insert(feed.isEmpty?0:1,MomentPromoFeedItem(
        id:'ad:'+ad.id,
        backgroundImagePath:'',logoImagePath:'',
        title:ad.title,subtitle:ad.subtitle,
        imageBytes:ad.imageBytes,
        minimumVisibleMs:ad.minimumVisibleMs,
        onVisible:(milliseconds)=>unawaited(_sponsorVisible(milliseconds)),
      ));
    }
    return Stack(children:[
      MomentsScreen(
      key:const Key('orbit_m7_live_moments'),
      stories:stories,feedItems:feed,privateMode:true,
      pendingCard:_pendingCard(),
      hasMore:_hasMore && !_showingOfflinePreviews,
      loadingMore:_loadingMore,
      onLoadMore:()=>unawaited(_loadMore()),
      privateReadOnly:_showingOfflinePreviews,
      privateBookmarking:true,
      privateSharing:true,
      viewState:_busy?MomentsViewState.loading:
        _error!=null?MomentsViewState.error:
        _showingOfflinePreviews && feed.isEmpty?MomentsViewState.error:
        feed.isEmpty?MomentsViewState.empty:MomentsViewState.populated,
      errorMessage:_error??'Moments unavailable.',
      onRefresh:()=>_load(retryDrafts:true),
      onSearchPressed:(){},onFilterPressed:()=>unawaited(_load()),
      onMessagesPressed:(){},
      onStoryPressed:(story)=>_openById(story.id,storyGroup:true),
      onLikeChanged:(item,liked)=>unawaited(_react(item,liked)),
      onCommentPressed:(item)=>_openById(item.id,comments:true),
      onBookmarkChanged:(item,value)=>unawaited(_setBookmark(item,value)),
      onSharePressed:(item)=>unawaited(_shareAuthorizedMoment(item)),
      onTextMenuPressed:(item){},
      onFeedItemPressed:(item){
        if(item is MomentPromoFeedItem){
          unawaited(_openSponsored());
        }else if(item is MomentTextFeedItem && item.isCheckIn){
          unawaited(_openActivityCheckIn(item.id));
        }else{_openById(item.id);}
      },
      onTabSelected:widget.onTabSelected,onAddPressed:(){},
      cameraBuilder:(_)=>_camera(),
    ),
    if(_showingOfflinePreviews)Positioned(
      top:68,left:16,right:16,
      child:Material(
        color:AppColors.background,
        elevation:2,
        borderRadius:BorderRadius.circular(16),
        child:Padding(padding:const EdgeInsets.all(12),
          child:Text('Offline preview · access will expire soon',
            textAlign:TextAlign.center,style:AppTypography.bodyMuted)),
      ),
    ),

    ]);
  }
}
