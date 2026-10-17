import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// App-start gate for Orbit's launch artwork.
///
/// Release/profile behavior:
/// - shown once when the app process starts
/// - waits [displayDuration]
/// - fades into the existing Orbit application
///
/// Debug behavior:
/// - a normal hot reload calls [reassemble]
/// - the splash is intentionally replayed so the launch artwork can be
///   inspected while developing without stopping the app
///
/// The existing [child] remains the real Orbit application root; this widget
/// does not replace Orbit navigation, routes, popup architecture, or screens.
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
    _scheduleFinish();
  }

  void _scheduleFinish() {
    _timer?.cancel();
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
  void reassemble() {
    super.reassemble();

    // Hot reload does not rerun main() or initState(). Replaying the splash
    // here is debug-only and gives the user an immediate visual check of the
    // real launch screen while iterating.
    if (!kDebugMode) {
      return;
    }

    _timer?.cancel();

    if (mounted) {
      setState(() {
        _showSplash = true;
      });
      _scheduleFinish();
    }
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
                return const ColoredBox(color: Colors.white);
              },
        ),
      ),
    );
  }
}
