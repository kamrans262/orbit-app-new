import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays Orbit's launch artwork before the real app root.
///
/// The splash fills the entire device viewport, while the artwork uses
/// [BoxFit.contain] so the full splash artwork/logo is always visible and is
/// never cropped on tall or narrow phones.
///
/// This gate lives above MaterialApp, so it provides its own Directionality.
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
  bool _didNotifyFinished = false;

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

    if (!_didNotifyFinished) {
      _didNotifyFinished = true;
      widget.onSplashFinished?.call();
    }

    setState(() {
      _showSplash = false;
    });
  }

  @override
  void reassemble() {
    super.reassemble();

    if (!kDebugMode || !mounted) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _showSplash = true;
    });

    _scheduleFinish();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: widget.fadeDuration,
        reverseDuration: widget.fadeDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topLeft,
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
      ),
    );
  }
}

class _OrbitSplashArtwork extends StatelessWidget {
  const _OrbitSplashArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      // Full-screen Orbit background. The artwork itself is contained so
      // no logo/artwork pixels are clipped by the device aspect ratio.
      color: Color(0xFFF9F9F9),
      child: SizedBox.expand(child: _ContainedSplashImage()),
    );
  }
}

class _ContainedSplashImage extends StatelessWidget {
  const _ContainedSplashImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/splash.png',
      key: const ValueKey<String>('orbit-splash-image'),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return const SizedBox.expand();
          },
    );
  }
}
