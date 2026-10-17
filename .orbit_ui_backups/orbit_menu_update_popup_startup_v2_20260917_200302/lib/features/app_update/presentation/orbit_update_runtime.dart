import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models/update_popup_data.dart';
import '../domain/orbit_installed_version.dart';
import 'widgets/update_available_popup.dart';

/// Central, backend-ready source for Orbit release/update presentation data.
///
/// Replace [latestVersion] and [changes] with API/config values later without
/// changing the startup gate or More Menu integration.
abstract final class OrbitUpdateReleaseCatalog {
  static const String latestVersion = '2.5.0';

  static const String title = 'Update Available';
  static const String description =
      'A new version of Orbit is available with new features and improvements.';

  static const List<String> changes = <String>[
    'Improved performance & stability',
    'New dashboard widgets',
    'Bug fixes and security updates',
  ];

  static UpdatePopupData latestReleaseData() {
    return UpdatePopupData(
      currentVersion: _displayVersion(kOrbitInstalledAppVersion),
      newVersion: _displayVersion(latestVersion),
      title: title,
      description: description,
      changes: changes,
    );
  }
}

/// True only when [latestVersion] is numerically newer than [currentVersion].
/// Handles values such as 2.5, 2.5.0, v2.5.0 and 2.5.0+12.
bool isOrbitVersionNewer(String latestVersion, String currentVersion) {
  final latest = _parseVersion(latestVersion);
  final current = _parseVersion(currentVersion);
  final count = latest.length > current.length ? latest.length : current.length;

  for (var index = 0; index < count; index++) {
    final latestPart = index < latest.length ? latest[index] : 0;
    final currentPart = index < current.length ? current[index] : 0;
    if (latestPart != currentPart) {
      return latestPart > currentPart;
    }
  }
  return false;
}

List<int> _parseVersion(String value) {
  var normalized = value.trim();
  if (normalized.startsWith('v') || normalized.startsWith('V')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.split('+').first.split('-').first;

  final values = <int>[];
  for (final part in normalized.split('.')) {
    final match = RegExp(r'^\d+').firstMatch(part.trim());
    values.add(int.tryParse(match?.group(0) ?? '') ?? 0);
  }
  return values.isEmpty ? <int>[0] : values;
}

String _displayVersion(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return 'v${trimmed.substring(1)}';
  }
  return 'v$trimmed';
}

/// Opens the same release/update popup manually from Orbit Menu -> What's New.
Future<UpdatePopupResult?> showLatestOrbitUpdatePopup(BuildContext context) {
  return showUpdateAvailablePopup(
    context,
    data: OrbitUpdateReleaseCatalog.latestReleaseData(),
  );
}

/// App-wide startup gate. It is intentionally disabled by default so widget
/// tests that instantiate OrbitApp directly are not interrupted by a modal.
/// main.dart enables it for a real app launch.
class OrbitUpdateNavigatorObserver extends NavigatorObserver {
  OrbitUpdateNavigatorObserver._();

  static final OrbitUpdateNavigatorObserver instance =
      OrbitUpdateNavigatorObserver._();

  static bool autoCheckEnabled = false;

  bool _startupCheckScheduled = false;
  bool _startupPopupHandled = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _scheduleStartupCheck();
  }

  void _scheduleStartupCheck() {
    if (!autoCheckEnabled || _startupCheckScheduled || _startupPopupHandled) {
      return;
    }
    _startupCheckScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupCheck());
    });
  }

  Future<void> _runStartupCheck() async {
    // Gives the first visible Orbit route time to settle. The dialog uses the
    // root Navigator context, so if navigation changes during this delay it is
    // still shown over whichever screen is currently visible.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (_startupPopupHandled) {
      return;
    }

    final navigatorState = navigator;
    if (navigatorState == null || !navigatorState.mounted) {
      _startupCheckScheduled = false;
      return;
    }

    if (!isOrbitVersionNewer(
      OrbitUpdateReleaseCatalog.latestVersion,
      kOrbitInstalledAppVersion,
    )) {
      _startupPopupHandled = true;
      return;
    }

    _startupPopupHandled = true;
    await showUpdateAvailablePopup(
      navigatorState.context,
      data: OrbitUpdateReleaseCatalog.latestReleaseData(),
    );
  }
}
