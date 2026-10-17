import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/orbit_connection_probe.dart';
import 'widgets/offline_popup.dart';

/// App-wide offline monitor for Orbit.
///
/// Startup is intentionally guarded by a grace period and two consecutive
/// failed probes. This prevents a transient DNS/network warm-up failure from
/// showing "You're Offline" immediately after the app opens.
class OrbitConnectivityNavigatorObserver extends NavigatorObserver
    with WidgetsBindingObserver {
  OrbitConnectivityNavigatorObserver._();

  static final OrbitConnectivityNavigatorObserver instance =
      OrbitConnectivityNavigatorObserver._();

  static bool autoMonitorEnabled = false;
  static Duration pollInterval = const Duration(seconds: 12);
  static Duration startupGracePeriod = const Duration(seconds: 8);
  static Duration confirmationDelay = const Duration(seconds: 2);

  Timer? _timer;
  Timer? _startupTimer;
  bool _bindingObserverInstalled = false;
  bool _checkScheduled = false;
  bool _checkInFlight = false;
  bool _popupVisible = false;
  bool _dismissedForCurrentOfflineEpisode = false;
  bool _startupGraceComplete = false;
  int _consecutiveFailures = 0;

  /// Called once the splash has completed. Monitoring starts quietly and does
  /// not show a popup during the initial startup grace period.
  static void startMonitoringAfterStartup() {
    autoMonitorEnabled = true;
    instance._beginMonitoringAfterGrace();
  }

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
    if (state == AppLifecycleState.resumed && _startupGraceComplete) {
      _scheduleCheck(delay: const Duration(milliseconds: 750));
    }
  }

  void _beginMonitoringAfterGrace() {
    if (!autoMonitorEnabled) {
      return;
    }

    _installObserversAndTimer();

    _startupTimer?.cancel();
    _startupGraceComplete = false;
    _consecutiveFailures = 0;
    _startupTimer = Timer(startupGracePeriod, () {
      _startupGraceComplete = true;
      unawaited(checkNow());
    });
  }

  void _ensureMonitoring() {
    if (!autoMonitorEnabled) {
      return;
    }

    _installObserversAndTimer();

    if (_startupGraceComplete) {
      _scheduleCheck(delay: const Duration(milliseconds: 700));
    }
  }

  void _installObserversAndTimer() {
    if (!_bindingObserverInstalled) {
      WidgetsBinding.instance.addObserver(this);
      _bindingObserverInstalled = true;
    }

    _timer ??= Timer.periodic(pollInterval, (_) {
      if (_startupGraceComplete) {
        unawaited(checkNow());
      }
    });
  }

  void _scheduleCheck({required Duration delay}) {
    if (!autoMonitorEnabled || !_startupGraceComplete || _checkScheduled) {
      return;
    }

    _checkScheduled = true;
    Future<void>.delayed(delay, () {
      _checkScheduled = false;
      if (autoMonitorEnabled && _startupGraceComplete) {
        unawaited(checkNow());
      }
    });
  }

  Future<void> checkNow() async {
    if (!autoMonitorEnabled ||
        !_startupGraceComplete ||
        _checkInFlight ||
        _popupVisible) {
      return;
    }

    final initialNavigator = navigator;
    if (initialNavigator == null || !initialNavigator.mounted) {
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
      _consecutiveFailures = 0;
      _dismissedForCurrentOfflineEpisode = false;
      return;
    }

    _consecutiveFailures += 1;

    // One failed probe is not enough to interrupt the user. Confirm once more
    // after a short delay before showing the offline popup.
    if (_consecutiveFailures < 2) {
      _scheduleCheck(delay: confirmationDelay);
      return;
    }

    if (_dismissedForCurrentOfflineEpisode || _popupVisible) {
      return;
    }

    final currentNavigator = navigator;
    if (currentNavigator == null || !currentNavigator.mounted) {
      return;
    }

    _popupVisible = true;
    final result = await showOrbitOfflinePopup(
      currentNavigator.context,
      onRetry: OrbitConnectionProbe.check,
    );
    _popupVisible = false;

    if (result == OrbitOfflinePopupResult.restored) {
      _consecutiveFailures = 0;
      _dismissedForCurrentOfflineEpisode = false;
    } else {
      _dismissedForCurrentOfflineEpisode = true;
    }
  }

  void resetSessionState() {
    _timer?.cancel();
    _startupTimer?.cancel();
    _timer = null;
    _startupTimer = null;
    _checkScheduled = false;
    _checkInFlight = false;
    _popupVisible = false;
    _dismissedForCurrentOfflineEpisode = false;
    _startupGraceComplete = false;
    _consecutiveFailures = 0;

    if (_bindingObserverInstalled) {
      WidgetsBinding.instance.removeObserver(this);
      _bindingObserverInstalled = false;
    }
  }
}
