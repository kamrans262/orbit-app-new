import 'dart:async';

import 'package:flutter/material.dart';

/// App-start gate for the Orbit launch artwork.
///
/// This widget deliberately sits *outside* [OrbitApp], so the regular Orbit
/// navigator, update observer, connectivity observer, routes and popup system
/// are not rebuilt or replaced. Once the splash period completes, [child] is
/// revealed and continues as the normal application root.
class OrbitSplashGate extends StatefulWidget {
  const OrbitSplashGate({
    required this.child,
    this.displayDuration = const Duration(seconds: 2),
    this.fadeDuration = const Duration(milliseconds: 280),
    this.onSplashFinished,
    super.key,
  });

  final Widget child;
  final Duration displayDuration;
  final Duration fadeDuration;
  final VoidCallback? onSplashFinished;

  @override
  State<OrbitSplashGate> createState() => _OrbitSplashGateState();
}

class _OrbitSplashGateState extends State<OrbitSplashGate> {
  Timer? _timer;
  bool _showSplash = true;
  bool _finishedCallbackSent = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.displayDuration, _finishSplash);
  }

  void _finishSplash() {
    if (!mounted || !_showSplash) {
      return;
    }

    if (!_finishedCallbackSent) {
      _finishedCallbackSent = true;
      widget.onSplashFinished?.call();
    }

    setState(() {
      _showSplash = false;
    });
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
      reverseDuration: widget.fadeDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _showSplash
          ? const _OrbitSplashArtwork(
              key: ValueKey<String>('orbit-splash-artwork'),
            )
          : KeyedSubtree(
              key: const ValueKey<String>('orbit-live-app'),
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
          key: const ValueKey<String>('orbit-splash-image'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                // Preserve full-screen geometry even if a development asset is
                // temporarily unavailable. The installer verifies the real asset.
                return const ColoredBox(color: Colors.white);
              },
        ),
      ),
    );
  }
}
