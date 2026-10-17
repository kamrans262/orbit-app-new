import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/sos_models.dart';

class SosTrigger extends StatefulWidget {
  const SosTrigger({required this.onTriggered, super.key});

  final ValueChanged<SosAlertSubmission> onTriggered;

  @override
  State<SosTrigger> createState() => _SosTriggerState();
}

class _SosTriggerState extends State<SosTrigger> with TickerProviderStateMixin {
  late final AnimationController _holdController;
  late final AnimationController _pulseController;
  late final AnimationController _tapController;

  bool _pressActive = false;
  bool _sentForCurrentPress = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener(_handleHoldStatus);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  void _handleHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _sentForCurrentPress) {
      return;
    }
    _sentForCurrentPress = true;
    widget.onTriggered(
      SosAlertSubmission(
        heldFor: const Duration(seconds: 3),
        sentAt: DateTime.now(),
      ),
    );
  }

  void _startPress(TapDownDetails _) {
    if (_pressActive) {
      return;
    }
    setState(() {
      _pressActive = true;
      _sentForCurrentPress = false;
    });
    _holdController.forward(from: 0);
    _pulseController.repeat();
    _tapController.forward();
  }

  void _finishPress([TapUpDetails? _]) {
    if (!_pressActive) {
      return;
    }
    final completed = _sentForCurrentPress;
    setState(() => _pressActive = false);
    _holdController.stop();
    _holdController.reset();
    _pulseController.stop();
    _pulseController.reset();
    _tapController.reverse();

    if (!completed) {
      _tapController.forward(from: 0).then<void>((_) {
        if (mounted) {
          _tapController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _holdController
      ..removeStatusListener(_handleHoldStatus)
      ..dispose();
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  double _ringWave(int index) {
    if (!_pressActive) {
      return 0;
    }
    final phase = (_pulseController.value - (index * 0.16)) % 1.0;
    if (phase < 0.0) {
      return 0;
    }
    return math.sin(phase * math.pi).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _holdController,
        _pulseController,
        _tapController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final tapScale = 1 + (_tapController.value * 0.025);
        final holdScale = _pressActive ? 1.025 : 1.0;
        return SizedBox.square(
          dimension: 264,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _PulseRing(
                size: 264,
                borderColor: const Color(0x3AE33A3A),
                fillColor: const Color(0x081F0000),
                scale: 1 + (_ringWave(2) * 0.035),
              ),
              _PulseRing(
                size: 232,
                borderColor: const Color(0x56E33A3A),
                fillColor: const Color(0x0D3A0000),
                scale: 1 + (_ringWave(1) * 0.03),
              ),
              _PulseRing(
                size: 200,
                borderColor: const Color(0x75E83C3C),
                fillColor: const Color(0x143F0000),
                scale: 1 + (_ringWave(0) * 0.025),
              ),
              Transform.scale(
                scale: tapScale * holdScale,
                child: Semantics(
                  button: true,
                  label: 'Hold SOS for 3 seconds',
                  child: GestureDetector(
                    key: const ValueKey<String>('sos-trigger-button'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _startPress,
                    onTapUp: _finishPress,
                    onTapCancel: _finishPress,
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          radius: 0.85,
                          colors: <Color>[
                            Color(0xFFE84040),
                            Color(0xFFC01818),
                            Color(0xFF8C0E0E),
                          ],
                          stops: <double>[0, 0.68, 1],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _pressActive
                                ? const Color(0x88B90E18)
                                : const Color(0x553D0000),
                            blurRadius: _pressActive ? 34 : 24,
                            spreadRadius: _pressActive ? 10 : 6,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'HOLD',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.2,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                child: SizedBox(
                  width: 150,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _pressActive ? _holdController.value : 0,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0x66F44336),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.size,
    required this.borderColor,
    required this.fillColor,
    required this.scale,
  });

  final double size;
  final Color borderColor;
  final Color fillColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(width: 1, color: borderColor),
          ),
        ),
      ),
    );
  }
}
