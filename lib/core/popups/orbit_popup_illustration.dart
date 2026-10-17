import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum OrbitPopupIllustrationMotion {
  none,
  pulse,
  locationPulse,
  slideRight,
  scaleIn,
  breathe,
  cameraPulse,
  warningPulse,
  reload,
  batteryEntry,
  microphoneBreathe,
}

class OrbitPopupIllustration extends StatefulWidget {
  const OrbitPopupIllustration({
    required this.assetPath,
    this.motion = OrbitPopupIllustrationMotion.none,
    this.width = 100,
    this.height = 100,
    this.svgWidth,
    this.svgHeight,
    this.backgroundColor,
    this.backgroundSize,
    this.fit = BoxFit.contain,
    super.key,
  });

  final String assetPath;
  final OrbitPopupIllustrationMotion motion;
  final double width;
  final double height;
  final double? svgWidth;
  final double? svgHeight;
  final Color? backgroundColor;
  final double? backgroundSize;
  final BoxFit fit;

  @override
  State<OrbitPopupIllustration> createState() => _OrbitPopupIllustrationState();
}

class _OrbitPopupIllustrationState extends State<OrbitPopupIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.motion == OrbitPopupIllustrationMotion.reload
          ? const Duration(milliseconds: 1050)
          : const Duration(milliseconds: 620),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfAllowed());
  }

  @override
  void didUpdateWidget(covariant OrbitPopupIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _controller
        ..stop()
        ..reset();
      _startIfAllowed();
    }
  }

  void _startIfAllowed() {
    if (!mounted) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || widget.motion == OrbitPopupIllustrationMotion.none) {
      return;
    }
    if (widget.motion == OrbitPopupIllustrationMotion.reload) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final illustration = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(child: _buildGraphic()),
    );

    if (reduceMotion || widget.motion == OrbitPopupIllustrationMotion.none) {
      return illustration;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: illustration,
      builder: (context, child) {
        final value = _controller.value;
        var scale = 1.0;
        var dx = 0.0;
        var dy = 0.0;
        var turns = 0.0;

        switch (widget.motion) {
          case OrbitPopupIllustrationMotion.none:
            break;
          case OrbitPopupIllustrationMotion.pulse:
          case OrbitPopupIllustrationMotion.locationPulse:
            scale = _threePoint(value, 0.94, 1.045, 1);
            break;
          case OrbitPopupIllustrationMotion.slideRight:
            dx = _threePoint(value, -7, 3, 0);
            break;
          case OrbitPopupIllustrationMotion.scaleIn:
            scale = _threePoint(value, 0.9, 1.035, 1);
            break;
          case OrbitPopupIllustrationMotion.breathe:
            scale = _threePoint(value, 0.96, 1.03, 1);
            break;
          case OrbitPopupIllustrationMotion.cameraPulse:
            scale = _threePoint(value, 1, 1.035, 1);
            break;
          case OrbitPopupIllustrationMotion.warningPulse:
            scale = _threePoint(value, 0.92, 1.06, 1);
            break;
          case OrbitPopupIllustrationMotion.reload:
            turns = value;
            break;
          case OrbitPopupIllustrationMotion.batteryEntry:
            scale = _threePoint(value, 0.95, 1.02, 1);
            dy = _threePoint(value, 8, -2, 0);
            break;
          case OrbitPopupIllustrationMotion.microphoneBreathe:
            scale = _threePoint(value, 0.96, 1.035, 1);
            break;
        }

        Widget transformed = Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(scale: scale, child: child),
        );
        if (widget.motion == OrbitPopupIllustrationMotion.reload) {
          transformed = Transform.rotate(
            angle: turns * math.pi * 2,
            child: transformed,
          );
        }
        return transformed;
      },
    );
  }

  Widget _buildGraphic() {
    final svg = SvgPicture.asset(
      widget.assetPath,
      width: widget.svgWidth,
      height: widget.svgHeight,
      fit: widget.fit,
    );
    final backgroundColor = widget.backgroundColor;
    if (backgroundColor == null) {
      return svg;
    }

    final size = widget.backgroundSize ?? math.min(widget.width, widget.height);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
      child: svg,
    );
  }

  double _threePoint(double t, double start, double middle, double end) {
    if (t <= 0.62) {
      final local = Curves.easeOutCubic.transform(
        (t / 0.62).clamp(0.0, 1.0).toDouble(),
      );
      return start + ((middle - start) * local);
    }
    final local = Curves.easeOutCubic.transform(
      ((t - 0.62) / 0.38).clamp(0.0, 1.0).toDouble(),
    );
    return middle + ((end - middle) * local);
  }
}
