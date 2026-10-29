import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_ping_repository.dart';
import '../../data/orbit_ping_notification_preferences.dart';
import 'orbit_ping_navigation.dart';
import '../widgets/orbit_ping_feedback.dart';

/// In-app foreground-only notice on authenticated, non-Home pages.
/// Home owns its existing incoming-sheet refresh. No background push,
/// realtime socket or fake delivery receipt is implied.
class OrbitPingForegroundObserver extends NavigatorObserver with WidgetsBindingObserver {
  final OrbitPingRepository _repository=OrbitPingRepository();
  final Set<String> _announced=<String>{};
  Timer? _clock;
  Route<dynamic>? _top;
  String? _owner;
  bool _busy=false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _clock=Timer.periodic(const Duration(seconds:25), (_) => unawaited(_refresh()));
  }
  void close() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _announced.clear();
  }

  @override
  void didPush(Route<dynamic> route,Route<dynamic>? previousRoute) {
    _top=route;
    if(route.settings.name==AppRoutes.login || route.settings.name==AppRoutes.welcome) {
      _owner=null;_announced.clear();
    }
    super.didPush(route,previousRoute);
  }
  @override
  void didPop(Route<dynamic> route,Route<dynamic>? previousRoute) {
    _top=previousRoute;
    super.didPop(route,previousRoute);
  }
  @override
  void didReplace({Route<dynamic>? newRoute,Route<dynamic>? oldRoute}) {
    if(identical(_top,oldRoute))_top=newRoute;
    super.didReplace(newRoute:newRoute,oldRoute:oldRoute);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed)unawaited(_refresh());
  }

  Future<void> _openAuthorized(OrbitPingRecord announced) async {
    try {
      // Revalidate current identity, blocks, privacy and Circle access
      // before rendering content from an earlier foreground notice.
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null || owner!=_owner || _top is! PageRoute)return;
      final current=await _repository.detail(announced.id);
      final context=navigator?.context;
      if(context==null || !context.mounted || owner!=_owner)return;
      await OrbitPingNavigation.showIncoming(context,current,repository:_repository);
    }catch(_){
      final context=navigator?.context;
      if(context!=null && context.mounted) {
        OrbitPingFeedback.show(context,'This Ping is no longer available.');
      }
    }
  }

  Future<void> _refresh() async {
    if(_busy || WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed)return;
    // Never interrupt an open dialog, camera overlay, onboarding or Home's
    // own Ping polling. The Navigator observer tracks actual visible routes.
    if(_top is! PageRoute || _top?.settings.name==AppRoutes.home)return;
    _busy=true;
    try {
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null){_owner=null;_announced.clear();return;}
      if(_owner!=owner) {
        _owner=owner;
        _announced.clear();
      }
      if(!await _repository.available())return;
      await _repository.flushPending();
      if(!await OrbitPingNotificationPreferences.instance.alertsEnabled())return;
      String? cursor;
      for(var i=0;i<4;i++){
        final page=await _repository.page('inbox',cursor:cursor);
        if(_top is! PageRoute || _top?.settings.name==AppRoutes.home)return;
        for(final ping in page.items){
          if(ping.status=='seen'||_announced.contains(ping.id))continue;
          final context=navigator?.context;
          if(context==null || !context.mounted)return;
          _announced.add(ping.id);
          // The notification itself does not count as Delivered or Seen.
          OrbitPingFeedback.show(context,'You have a new Ping.',actionLabel:'View',
            onRetry:(){
              unawaited(_openAuthorized(ping));
            });
          return;
        }
        if(page.nextCursor==null)break;
        cursor=page.nextCursor;
      }
    }catch(_){
      // Foreground HTTP can be unavailable; never claim notification delivery.
    }finally{_busy=false;}
  }
}
