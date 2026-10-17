import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/group_chat_models.dart';
import 'chat_timestamp.dart';

class SentVoiceMessage extends StatefulWidget {
  const SentVoiceMessage({required this.message, super.key});

  final GroupChatMessage message;

  @override
  State<SentVoiceMessage> createState() => _SentVoiceMessageState();
}

class _SentVoiceMessageState extends State<SentVoiceMessage> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _duration = widget.message.audioDuration ?? Duration.zero;
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
    final existing = _player;
    if (existing != null) return existing;

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
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
    return player;
  }

  Future<void> _togglePlayback() async {
    try {
      final player = _ensurePlayer();
      if (_isPlaying) {
        await player.pause();
        if (!mounted) return;
        setState(() => _isPlaying = false);
        return;
      }

      if (_hasStarted && _position > Duration.zero) {
        await player.resume();
      } else {
        final sourceValue = widget.message.audioUrl?.trim();
        if (sourceValue == null || sourceValue.isEmpty) return;
        final Source source;
        if (sourceValue.startsWith('http://') ||
            sourceValue.startsWith('https://')) {
          source = UrlSource(sourceValue);
        } else {
          final relativePath = sourceValue.startsWith('assets/')
              ? sourceValue.substring('assets/'.length)
              : sourceValue;
          source = AssetSource(relativePath);
        }
        await player.play(source);
        _hasStarted = true;
      }
      if (!mounted) return;
      setState(() => _isPlaying = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Unable to play this voice message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.78,
      330.0,
    );
    final totalMs = _duration.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                ),
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
                      color: Colors.white,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _togglePlayback,
                        customBorder: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: 34,
                          child: Center(
                            child: _isPlaying
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
                        width: 135,
                        height: 28,
                        child: CustomPaint(
                          painter: _WaveformPainter(progress: progress),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDuration(_duration),
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            ChatTimestamp(widget.message.timestamp, alignment: TextAlign.right),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final safeDuration = duration.isNegative ? Duration.zero : duration;
    final minutes = safeDuration.inMinutes;
    final seconds = safeDuration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    const strokeWidth = 2.2;
    final gap = (size.width - (barCount * strokeWidth)) / (barCount - 1);
    final activePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < barCount; index++) {
      final x = (index * (strokeWidth + gap)) + (strokeWidth / 2);
      final normalized = (math.sin(index * 0.93).abs() * 0.65) + 0.25;
      final barHeight = math.max(5.0, size.height * normalized);
      final top = (size.height - barHeight) / 2;
      final paint = x <= size.width * progress ? activePaint : inactivePaint;
      canvas.drawLine(Offset(x, top), Offset(x, top + barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
