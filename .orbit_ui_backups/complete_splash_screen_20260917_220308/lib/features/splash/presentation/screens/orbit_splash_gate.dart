import 'dart:async';

import 'package:flutter/material.dart';

/// Shows the branded Orbit splash image once, then reveals the existing app.
///
/// Keeping the splash outside the app's [MaterialApp] means existing routes,
/// navigator observers, popup startup checks, and navigation behavior are left
/// untouched until the splash has completed.
class OrbitSplashGate extends StatefulWidget {
  const OrbitSplashGate({
    required this.child,
    this.displayDuration = const Duration(seconds: 2),
    this.fadeDuration = const Duration(milliseconds: 280),
    super.key,
  });

  final Widget child;
  final Duration displayDuration;
  final Duration fadeDuration;

  @override
  State<OrbitSplashGate> createState() => _OrbitSplashGateState();
}

class _OrbitSplashGateState extends State<OrbitSplashGate> {
  Timer? _timer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.displayDuration, _finishSplash);
  }

  @override
  void didUpdateWidget(covariant OrbitSplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_showSplash && oldWidget.displayDuration != widget.displayDuration) {
      _timer?.cancel();
      _timer = Timer(widget.displayDuration, _finishSplash);
    }
  }

  void _finishSplash() {
    if (!mounted || !_showSplash) return;
    setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.fadeDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _showSplash
          ? const _OrbitSplashArtwork(key: ValueKey<String>('orbit-splash'))
          : KeyedSubtree(
              key: const ValueKey<String>('orbit-app'),
              child: widget.child,
            ),
    );
  }
}

class _OrbitSplashArtwork extends StatelessWidget {
  const _OrbitSplashArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox.expand(
        child: Image.asset(
          'assets/splash.png',
          key: const Key('orbit-splash-image'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
