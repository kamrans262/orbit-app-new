import 'package:flutter/material.dart';

/// Shared app-wide page transition: a light fade with a subtle horizontal
/// slide. MaterialPageRoute supplies the ~300ms route duration, while this
/// builder keeps the visual transition consistent on every supported platform.
class AppFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.035, 0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(position: slideAnimation, child: child),
    );
  }
}

abstract final class AppPageTransitions {
  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: AppFadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: AppFadeSlidePageTransitionsBuilder(),
      TargetPlatform.macOS: AppFadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: AppFadeSlidePageTransitionsBuilder(),
      TargetPlatform.linux: AppFadeSlidePageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppFadeSlidePageTransitionsBuilder(),
    },
  );
}
