import 'package:flutter/material.dart';

import 'share_moments_screen.dart';

/// Backward-compatible wrapper for code created before the screen received its
/// semantic name. New code should use [ShareMomentsScreen].
@Deprecated('Use ShareMomentsScreen instead.')
class Welcome3Screen extends ShareMomentsScreen {
  const Welcome3Screen({required super.onNext, super.key});
}

/// Backward-compatible key names for older tests/code.
@Deprecated('Use ShareMomentsKeys instead.')
abstract final class Welcome3Keys {
  static const heading = ShareMomentsKeys.heading;
  static const body = ShareMomentsKeys.body;
  static const image = ShareMomentsKeys.image;
  static const nextButton = ShareMomentsKeys.nextButton;
}
