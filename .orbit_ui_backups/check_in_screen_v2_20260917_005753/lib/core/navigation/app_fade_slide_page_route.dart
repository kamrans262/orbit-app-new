import 'package:flutter/material.dart';

class AppFadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  AppFadeSlidePageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(position: slide, child: child),
          );
        },
      );
}
