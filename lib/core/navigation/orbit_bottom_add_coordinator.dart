import 'package:flutter/material.dart';

typedef OrbitBottomAddHandler = void Function(BuildContext context);

/// Central action for the + button in the shared Orbit bottom navigation.
///
/// The shared bottom bar uses this first, so the + action stays identical
/// regardless of which screen currently owns the bottom navigation.
///
/// Existing per-screen callbacks remain as a fallback for isolated widget tests
/// or screens rendered without the app-level coordinator configured.
abstract final class OrbitBottomAddCoordinator {
  static OrbitBottomAddHandler? _handler;

  static void configure(OrbitBottomAddHandler handler) {
    _handler = handler;
  }

  static bool open(BuildContext context) {
    final handler = _handler;
    if (handler == null) {
      return false;
    }

    handler(context);
    return true;
  }
}
