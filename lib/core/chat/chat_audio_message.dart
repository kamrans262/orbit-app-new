import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/app_typography.dart';

class ChatAudioMessage extends StatefulWidget {
  const ChatAudioMessage({
    required this.audioSource,
    required this.duration,
    required this.timestamp,
    required this.isMine,
    this.maxWidth = 330,
    super.key,
  });

  final String audioSource;
  final Duration duration;
  final String timestamp;
  final bool isMine;
  final double maxWidth;

  @override
  State<ChatAudioMessage> createState() => _ChatAudioMessageState();
}

class _ChatAudioMessageState extends State<ChatAudioMessage> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;
  Duration _position = Duration.zero;
  late Duration _duration;
  bool _playing = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _duration = widget.duration;
  }

  @override
  void didUpdateWidget(covariant ChatAudioMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioSource != widget.audioSource) {
      _player?.stop();
      _position = Duration.zero;
      _duration = widget.duration;
      _started = false;
      _playing = false;
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  AudioPlayer _ensurePlayer() {
    final current = _player;
    if (current != null) return current;
    final player = AudioPlayer();
    _player = player;
    _positionSubscription = player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSubscription = player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _completeSubscription = player.onPlayerComplete.listen((event) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
    return player;
  }

  Future<void> _toggle() async {
    try {
      final player = _ensurePlayer();
      if (_playing) {
        await player.pause();
        if (mounted) setState(() => _playing = false);
        return;
      }
      if (_started && _position > Duration.zero) {
        await player.resume();
      } else {
        final sourceValue = widget.audioSource.trim();
        if (sourceValue.isEmpty) return;
        final Source source;
        if (sourceValue.startsWith('http://') ||
            sourceValue.startsWith('https://')) {
          source = UrlSource(sourceValue);
        } else {
          final relative = sourceValue.startsWith('assets/')
              ? sourceValue.substring('assets/'.length)
              : sourceValue;
          source = AssetSource(relative);
        }
        await player.play(source);
        _started = true;
      }
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Unable to play this audio message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = math.min(widget.maxWidth, screenWidth * 0.78);
    final totalMs = _duration.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();
    final mine = widget.isMine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: mine ? null : Colors.white,
                gradient: mine
                    ? const LinearGradient(
                        colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17.5,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Material(
                      color: mine ? Colors.white : const Color(0xFFF3E8FF),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _toggle,
                        customBorder: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: 34,
                          child: Center(
                            child: _playing
                                ? const Icon(
                                    Icons.pause_rounded,
                                    size: 20,
                                    color: Color(0xFF8B5CF6),
                                  )
                                : SvgPicture.asset(
                                    'assets/icons/play.svg',
                                    width: 16,
                                    height: 16,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFF8B5CF6),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: SizedBox(
                        width: 132,
                        height: 28,
                        child: CustomPaint(
                          painter: _ChatWaveformPainter(
                            progress: progress,
                            activeColor: mine
                                ? Colors.white
                                : const Color(0xFF8B5CF6),
                            inactiveColor: mine
                                ? const Color(0x66FFFFFF)
                                : const Color(0x558B5CF6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDuration(_duration),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: mine ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.timestamp,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                color: Color(0xFF8B95A1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes;
    final seconds = safe.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ChatWaveformPainter extends CustomPainter {
  const _ChatWaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    const strokeWidth = 2.2;
    final gap = (size.width - (barCount * strokeWidth)) / (barCount - 1);
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < barCount; index++) {
      final x = (index * (strokeWidth + gap)) + (strokeWidth / 2);
      final normalized = (math.sin(index * 0.93).abs() * 0.65) + 0.25;
      final barHeight = math.max(5.0, size.height * normalized);
      final top = (size.height - barHeight) / 2;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + barHeight),
        x <= size.width * progress ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
