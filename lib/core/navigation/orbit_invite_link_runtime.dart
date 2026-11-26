import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../app/routing/app_routes.dart';
import '../../features/auth/data/orbit_identity_client.dart';
import '../../features/friends/data/orbit_social_repository.dart';
import '../../features/circles/data/orbit_circle_repository.dart';
import '../../features/circles/presentation/screens/orbit_live_circles_screen.dart';
import '../../features/moments/data/orbit_moment_repository.dart';
import '../../features/moments/presentation/screens/orbit_live_moment_viewer.dart';
import '../../features/friends/presentation/screens/orbit_discover_friends_screen.dart';
import 'app_fade_slide_page_route.dart';
import 'orbit_moment_link.dart';

/// M4/M5 invitations and M7 references share one authenticated link router.
/// A Moment URL is not a bearer token: current Laravel ACLs must authorize it.
class OrbitInviteLinkRuntime extends NavigatorObserver {
  OrbitInviteLinkRuntime._();
  static final OrbitInviteLinkRuntime instance=OrbitInviteLinkRuntime._();

  final navigatorKey=GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _links;
  String? _pending;
  String? _pendingCircle;
  String? _pendingMoment;
  String? _route;
  Route<dynamic>? _homeRoute;
  String? _openingMoment;
  bool _opening=false;

  void initialize() {
    if(_links!=null)return;
    final links=AppLinks();
    _links=links.uriLinkStream.listen(_received,onError:(_){});
    links.getInitialLink().then((uri){
      if(uri!=null)_received(uri);
    }).catchError((Object _){});
  }

  void _received(Uri uri) {
    final moment=OrbitMomentLink.parse(uri);
    if(moment!=null){
      if(moment==_openingMoment)return;
      _pendingMoment=moment;
      _pending=null;
      _pendingCircle=null;
      _dispatch();
      return;
    }
    try{
      final code=OrbitSocialRepository().invitationCode(uri.toString());
      _pending=code;
      _pendingCircle=null;
      _pendingMoment=null;
      _dispatch();
      return;
    }on FormatException{
      // Not a friend invitation. Check the separate approved Circle format.
    }
    try{
      final code=OrbitCircleRepository().validateCode(uri.toString());
      _pendingCircle=code;
      _pending=null;
      _pendingMoment=null;
      _dispatch();
    }on FormatException{
      // Ignore unrecognized links, including untrusted URLs.
    }
  }

  @override
  void didPush(Route<dynamic> route,Route<dynamic>? previousRoute) {
    _route=route.settings.name;
    if(_route==AppRoutes.home)_homeRoute=route;
    if(_route==AppRoutes.home||_pendingMoment!=null)_dispatch();
  }

  @override
  void didReplace({Route<dynamic>? newRoute,Route<dynamic>? oldRoute}) {
    if(identical(_homeRoute,oldRoute))_homeRoute=null;
    _route=newRoute?.settings.name;
    if(_route==AppRoutes.home)_homeRoute=newRoute;
    if(_route==AppRoutes.home||_pendingMoment!=null)_dispatch();
  }

  @override
  void didPop(Route<dynamic> route,Route<dynamic>? previousRoute) {
    if(identical(_homeRoute,route))_homeRoute=null;
    _route=previousRoute?.settings.name;
    if(_route==AppRoutes.home)_homeRoute=previousRoute;
    if(_route==AppRoutes.home||_pendingMoment!=null)_dispatch();
  }

  @override
  void didRemove(Route<dynamic> route,Route<dynamic>? previousRoute){
    if(identical(_homeRoute,route))_homeRoute=null;
  }

  void _dispatch() {
    final onHome=_route==AppRoutes.home;
    final onAuthenticatedStack=_pendingMoment!=null&&_homeRoute?.isActive==true;
    if((_pending==null && _pendingCircle==null && _pendingMoment==null) ||
        _opening || (!onHome&&!onAuthenticatedStack))return;
    _opening=true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try{
        // Never open Moments, redeem invitations or navigate over sign-in.
        final state=await OrbitIdentityClient.instance.restoreSession();
        if(state!=OrbitRestoreState.authenticated)return;
        final nav=navigatorKey.currentState;
        if(nav==null || !nav.mounted)return;

        final momentId=_pendingMoment;
        if(momentId!=null){
          _openingMoment=momentId;
          final repository=OrbitMomentRepository();
          final owner=await repository.currentUserId();
          if(owner==null)return;
          final moment=await repository.authorizedMoment(momentId);
          final author=await repository.name(moment.creatorId);
          if(!nav.mounted||await repository.currentUserId()!=owner||_homeRoute?.isActive!=true)return;
          if(_pendingMoment==momentId)_pendingMoment=null;
          await nav.push<void>(AppFadeSlidePageRoute<void>(
            builder:(_)=>OrbitLiveMomentViewer(
              moment:moment,repository:repository,author:author),
          ));
          return;
        }

        final code=_pending;
        final circleCode=_pendingCircle;
        _pending=null;
        _pendingCircle=null;
        if(circleCode!=null){
          await nav.push<void>(AppFadeSlidePageRoute<void>(
            builder:(_)=>OrbitLiveCirclesScreen(initialInviteCode:circleCode),
          ));
        }else if(code!=null){
          await nav.push<void>(AppFadeSlidePageRoute<void>(
            builder:(_)=>OrbitDiscoverFriendsScreen(initialInviteCode:code),
          ));
        }
      }on OrbitIdentityException catch(error){
        // Keep a link only for transient errors. A rejected Moment URL
        // must not be retried forever after revocation, blocking or expiry.
        if(_pendingMoment!=null && error.statusCode!=null &&
            error.statusCode!>=400 && error.statusCode!<500 && error.statusCode!=401 && error.statusCode!=429){
          if(_pendingMoment==_openingMoment)_pendingMoment=null;
          final context=navigatorKey.currentContext;
          if(context!=null)ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content:Text('This Moment is unavailable or you do not have access.')));
        }
      }catch(_){
        // Leave a transient network-error link pending until next Home entry.
      }finally{
        final completed=_openingMoment;
        _openingMoment=null;_opening=false;
        if(completed!=null&&_pendingMoment!=null&&_pendingMoment!=completed)_dispatch();
      }
    });
  }
}
