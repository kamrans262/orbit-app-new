import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/orbit_connection_probe.dart';
import 'widgets/offline_popup.dart';

/// App-wide offline monitor for Orbit.
///
/// It is disabled by default so widget tests that instantiate OrbitApp do not
/// perform network work. main.dart enables it for real app launches.
class OrbitConnectivityNavigatorObserver extends NavigatorObserver
    with WidgetsBindingObserver {
  OrbitConnectivityNavigatorObserver._();

  static final OrbitConnectivityNavigatorObserver instance =
      OrbitConnectivityNavigatorObserver._();

  static bool autoMonitorEnabled = false;
  static Duration pollInterval = const Duration(seconds: 12);

  Timer? _timer;
  bool _bindingObserverInstalled = false;
  bool _checkScheduled = false;
  bool _checkInFlight = false;
  bool _popupVisible = false;
  bool _dismissedForCurrentOfflineEpisode = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _ensureMonitoring();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _ensureMonitoring();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _ensureMonitoring();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck(delay: const Duration(milliseconds: 250));
    }
  }

  void _ensureMonitoring() {
    if (!autoMonitorEnabled) {
      return;
    }

    if (!_bindingObserverInstalled) {
      WidgetsBinding.instance.addObserver(this);
      _bindingObserverInstalled = true;
    }

    _timer ??= Timer.periodic(pollInterval, (_) {
      unawaited(checkNow());
    });

    _scheduleCheck(delay: const Duration(milliseconds: 700));
  }

  void _scheduleCheck({required Duration delay}) {
    if (!autoMonitorEnabled || _checkScheduled) {
      return;
    }
    _checkScheduled = true;
    Future<void>.delayed(delay, () {
      _checkScheduled = false;
      unawaited(checkNow());
    });
  }

  /// Public primarily for retry hooks/tests and future backend/config wiring.
  Future<void> checkNow() async {
    if (!autoMonitorEnabled || _checkInFlight || _popupVisible) {
      return;
    }

    final navigatorState = navigator;
    if (navigatorState == null || !navigatorState.mounted) {
      return;
    }

    _checkInFlight = true;
    bool isOnline;
    try {
      isOnline = await OrbitConnectionProbe.check();
    } on Object {
      isOnline = false;
    } finally {
      _checkInFlight = false;
    }

    if (isOnline) {
      // Re-arm the popup only after the device has genuinely returned online.
      _dismissedForCurrentOfflineEpisode = false;
      return;
    }

    if (_dismissedForCurrentOfflineEpisode || _popupVisible) {
      return;
    }

    _popupVisible = true;
    final result = await showOrbitOfflinePopup(
      navigatorState.context,
      onRetry: OrbitConnectionProbe.check,
    );
    _popupVisible = false;

    if (result == OrbitOfflinePopupResult.restored) {
      _dismissedForCurrentOfflineEpisode = false;
    } else {
      // If the user closes the popup while still offline, do not immediately
      // nag them again. Periodic checks continue; once online is detected the
      // next future offline episode can display the popup again.
      _dismissedForCurrentOfflineEpisode = true;
    }
  }

  /// Test/support hook. Does not disable monitoring configuration.
  void resetSessionState() {
    _timer?.cancel();
    _timer = null;
    _checkScheduled = false;
    _checkInFlight = false;
    _popupVisible = false;
    _dismissedForCurrentOfflineEpisode = false;
    if (_bindingObserverInstalled) {
      WidgetsBinding.instance.removeObserver(this);
      _bindingObserverInstalled = false;
    }
  }
}
