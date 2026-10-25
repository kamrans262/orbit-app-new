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
    final isMoment=uri.scheme=='orbit' && uri.host=='moment' &&
      uri.pathSegments.length==1 && uri.query.isEmpty &&
      uri.userInfo.isEmpty && !uri.hasPort && uri.fragment.isEmpty &&
      RegExp(r'^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$')
        .hasMatch(uri.pathSegments.single);
    if(isMoment){
      _pendingMoment=uri.pathSegments.single;
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
    if(_route==AppRoutes.home)_dispatch();
  }

  @override
  void didReplace({Route<dynamic>? newRoute,Route<dynamic>? oldRoute}) {
    _route=newRoute?.settings.name;
    if(_route==AppRoutes.home)_dispatch();
  }

  @override
  void didPop(Route<dynamic> route,Route<dynamic>? previousRoute) {
    _route=previousRoute?.settings.name;
    if(_route==AppRoutes.home)_dispatch();
  }

  void _dispatch() {
    if((_pending==null && _pendingCircle==null && _pendingMoment==null) ||
        _opening || _route!=AppRoutes.home)return;
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
          final repository=OrbitMomentRepository();
          final moment=await repository.authorizedMoment(momentId);
          final author=await repository.name(moment.creatorId);
          if(!nav.mounted)return;
          _pendingMoment=null;
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
            error.statusCode!>=400 && error.statusCode!<500){
          _pendingMoment=null;
        }
      }catch(_){
        // Leave a transient network-error link pending until next Home entry.
      }finally{
        _opening=false;
      }
    });
  }
}
