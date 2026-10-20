import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../app/routing/app_routes.dart';
import '../../features/auth/data/orbit_identity_client.dart';
import '../../features/friends/data/orbit_social_repository.dart';
import '../../features/circles/data/orbit_circle_repository.dart';
import '../../features/circles/presentation/screens/orbit_live_circles_screen.dart';
import '../../features/friends/presentation/screens/orbit_discover_friends_screen.dart';
import 'app_fade_slide_page_route.dart';

/// Accepts only official Orbit invitation links. A cold-start link is held
/// in memory until verified authentication reaches Home; never auto-redeems.
class OrbitInviteLinkRuntime extends NavigatorObserver {
  OrbitInviteLinkRuntime._();
  static final OrbitInviteLinkRuntime instance = OrbitInviteLinkRuntime._();

  final navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _links;
  String? _pending;
  String? _pendingCircle;
  bool _opening = false;
  String? _route;

  void initialize() {
    if (_links != null) return;
    _links = AppLinks().uriLinkStream.listen(_received, onError: (_) {});
  }

  void _received(Uri url) {
    try {
      final code = OrbitSocialRepository().invitationCode(url.toString());
      _pending = code;
      _pendingCircle = null;
      _dispatch();
      return;
    } on FormatException {
      // A Circle URL has a different route and a separate strict code shape.
    }
    try {
      final code = OrbitCircleRepository().validateCode(url.toString());
      _pendingCircle = code;
      _pending = null;
      _dispatch();
    } on FormatException {
      // Never open arbitrary URLs or leak their payload to telemetry.
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _route = route.settings.name;
    if (_route == AppRoutes.home) _dispatch();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _route = newRoute?.settings.name;
    if (_route == AppRoutes.home) _dispatch();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // A valid link may arrive while another page is above Home. Re-evaluate
    // it on return; never redeem or open private data without auth.
    _route = previousRoute?.settings.name;
    if (_route == AppRoutes.home) _dispatch();
  }

  void _dispatch() {
    if ((_pending == null && _pendingCircle == null) ||
        _opening || _route != AppRoutes.home) return;
    _opening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // A link is a request to preview, not an authentication capability.
        final state = await OrbitIdentityClient.instance.restoreSession();
        if (state != OrbitRestoreState.authenticated) return;
        final nav = navigatorKey.currentState;
        final code = _pending;
        final circleCode = _pendingCircle;
        if (nav == null || !nav.mounted || (code == null && circleCode == null)) return;
        _pending = null;
        _pendingCircle = null;
        if (circleCode != null) {
          await nav.push<void>(AppFadeSlidePageRoute<void>(
            builder: (_) => OrbitLiveCirclesScreen(initialInviteCode: circleCode),
          ));
        } else if (code != null) {
          await nav.push<void>(AppFadeSlidePageRoute<void>(
            builder: (_) => OrbitDiscoverFriendsScreen(initialInviteCode: code),
          ));
        }
      } catch (_) {
        // Keep the link for manual retry. Never navigate through rejected auth.
      } finally {
        _opening = false;
      }
    });
  }
}
