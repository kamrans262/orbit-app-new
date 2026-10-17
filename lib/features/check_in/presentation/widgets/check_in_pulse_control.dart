import 'dart:math' as math;

import 'package:flutter/material.dart';

class CheckInPulseControl extends StatefulWidget {
  const CheckInPulseControl({
    required this.onTapSend,
    required this.onHoldSend,
    super.key,
  });

  final VoidCallback onTapSend;
  final VoidCallback onHoldSend;

  @override
  State<CheckInPulseControl> createState() => _CheckInPulseControlState();
}

class _CheckInPulseControlState extends State<CheckInPulseControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  bool _holding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_holding) return;
    _controller.stop();
    _controller.value = 0;
    await _controller.forward();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onTapSend();
  }

  void _holdStart(LongPressStartDetails details) {
    if (_holding) return;
    setState(() => _holding = true);
    _controller.repeat(reverse: true);
  }

  void _holdEnd(LongPressEndDetails details) {
    if (!_holding) return;
    _controller.stop();
    setState(() => _holding = false);
    _controller.animateBack(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    widget.onHoldSend();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxByWidth = math.max(170.0, constraints.maxWidth);
        final outerSize = math.min(220.0, maxByWidth);
        final scale = outerSize / 220.0;
        final centerSize = 90.0 * scale;
        final ringSizes = <double>[
          116.0 * scale,
          150.0 * scale,
          185.0 * scale,
          220.0 * scale,
        ];

        return SizedBox.square(
          dimension: outerSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  for (var index = ringSizes.length - 1; index >= 0; index--)
                    _PulseRing(
                      size: ringSizes[index],
                      index: index,
                      controllerValue: _controller.value,
                      holding: _holding,
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _tap,
                    onLongPressStart: _holdStart,
                    onLongPressEnd: _holdEnd,
                    child: Transform.scale(
                      scale:
                          1 + (_controller.value * (_holding ? 0.065 : 0.035)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.2, -0.25),
                            radius: 0.95,
                            colors: <Color>[
                              Color(0xFFF02AA5),
                              Color(0xFFD40D7B),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFFE63CA0)
                                  .withValues(alpha: _holding ? 0.42 : 0.25),
                              blurRadius: _holding ? 30 : 18,
                              spreadRadius: _holding ? 5 : 1,
                            ),
                          ],
                        ),
                        child: SizedBox.square(
                          dimension: centerSize,
                          child: Center(
                            child: Icon(
                              Icons.favorite_border_rounded,
                              color: Colors.white,
                              size: centerSize * 0.48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.size,
    required this.index,
    required this.controllerValue,
    required this.holding,
  });

  final double size;
  final int index;
  final double controllerValue;
  final bool holding;

  @override
  Widget build(BuildContext context) {
    const starts = <double>[0.00, 0.10, 0.20, 0.30];
    const ends = <double>[0.58, 0.68, 0.78, 0.88];
    final t = Curves.easeOutCubic.transform(
      ((controllerValue - starts[index]) / (ends[index] - starts[index])).clamp(
        0.0,
        1.0,
      ),
    );

    const borderColors = <Color>[
      Color(0x8CE650AA),
      Color(0x61DC50A0),
      Color(0x47D23C96),
      Color(0x2EC8328C),
    ];
    const centerColors = <Color>[
      Color(0x2EE63CA0),
      Color(0x1FDC3CA0),
      Color(0x14C8328C),
      Color(0x0FB42878),
    ];

    return Transform.scale(
      scale: 1 + t * (holding ? 0.065 : 0.035),
      child: Opacity(
        opacity: (0.72 + t * 0.28).clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColors[index], width: 1),
            gradient: RadialGradient(
              colors: <Color>[centerColors[index], Colors.transparent],
              stops: const <double>[0, 1],
            ),
          ),
        ),
      ),
    );
  }
}
