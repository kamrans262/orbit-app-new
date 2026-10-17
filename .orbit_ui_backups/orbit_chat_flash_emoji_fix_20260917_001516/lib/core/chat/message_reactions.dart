import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';

enum ChatReactionKind { heart, like, laugh, wow, sad, dislike }

extension ChatReactionKindX on ChatReactionKind {
  String get backendValue => switch (this) {
    ChatReactionKind.heart => '\u{2764}\u{FE0F}',
    ChatReactionKind.like => '\u{1F44D}',
    ChatReactionKind.laugh => '\u{1F602}',
    ChatReactionKind.wow => '\u{1F62E}',
    ChatReactionKind.sad => '\u{1F622}',
    ChatReactionKind.dislike => '\u{1F44E}',
  };

  String get semanticLabel => switch (this) {
    ChatReactionKind.heart => 'Love',
    ChatReactionKind.like => 'Like',
    ChatReactionKind.laugh => 'Laugh',
    ChatReactionKind.wow => 'Wow',
    ChatReactionKind.sad => 'Sad',
    ChatReactionKind.dislike => 'Dislike',
  };

  IconData get icon => switch (this) {
    ChatReactionKind.heart => Icons.favorite_rounded,
    ChatReactionKind.like => Icons.thumb_up_rounded,
    ChatReactionKind.laugh => Icons.sentiment_very_satisfied_rounded,
    ChatReactionKind.wow => Icons.sentiment_neutral,
    ChatReactionKind.sad => Icons.sentiment_dissatisfied_rounded,
    ChatReactionKind.dislike => Icons.thumb_down_rounded,
  };
}

typedef MessageReactionChanged = Future<void> Function(
  String messageId,
  ChatReactionKind? selected,
  Map<ChatReactionKind, int> counts,
);

class MessageReactionPicker extends StatelessWidget {
  const MessageReactionPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ChatReactionKind? selected;
  final ValueChanged<ChatReactionKind> onSelected;

  static Future<ChatReactionKind?> show({
    required BuildContext context,
    required Offset globalPosition,
    required ChatReactionKind? selected,
  }) async {
    final overlay = Overlay.of(context);
    final media = MediaQuery.of(context);
    const pickerWidth = 286.0;
    const pickerHeight = 56.0;
    final left = (globalPosition.dx - (pickerWidth / 2))
        .clamp(8.0, math.max(8.0, media.size.width - pickerWidth - 8))
        .toDouble();
    var top = globalPosition.dy - pickerHeight - 16;
    if (top < media.padding.top + 8) {
      top = globalPosition.dy + 16;
    }
    top = top
        .clamp(
          media.padding.top + 8,
          math.max(
            media.padding.top + 8,
            media.size.height - media.padding.bottom - pickerHeight - 8,
          ),
        )
        .toDouble();

    final completer = _ReactionCompleter();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => completer.complete(null),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: MessageReactionPicker(
                selected: selected,
                onSelected: completer.complete,
              ),
            ),
          ),
        ],
      ),
    );
    completer.onComplete = () => entry.remove();
    overlay.insert(entry);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 286,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ChatReactionKind.values
            .map((reaction) {
              final isSelected = reaction == selected;
              return Semantics(
                button: true,
                label: reaction.semanticLabel,
                selected: isSelected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelected(reaction),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0x1F7C3AED)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      reaction.icon,
                      size: 22,
                      color: reaction == ChatReactionKind.heart
                          ? const Color(0xFFFF4757)
                          : isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class MessageReactionSummary extends StatelessWidget {
  const MessageReactionSummary({
    required this.counts,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final Map<ChatReactionKind, int> counts;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final visible = counts.entries.where((entry) => entry.value > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        children: visible
            .map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7E2EE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      entry.key.icon,
                      size: 12,
                      color: entry.key == ChatReactionKind.heart
                          ? const Color(0xFFFF4757)
                          : const Color(0xFF7C3AED),
                    ),
                    if (entry.value > 1) ...<Widget>[
                      const SizedBox(width: 3),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class MessageReactionRegion extends StatefulWidget {
  const MessageReactionRegion({
    required this.messageId,
    required this.child,
    required this.isMine,
    this.initialSelected,
    this.initialCounts = const <ChatReactionKind, int>{},
    this.onChanged,
    super.key,
  });

  final String messageId;
  final Widget child;
  final bool isMine;
  final ChatReactionKind? initialSelected;
  final Map<ChatReactionKind, int> initialCounts;
  final MessageReactionChanged? onChanged;

  @override
  State<MessageReactionRegion> createState() => _MessageReactionRegionState();
}

class _MessageReactionRegionState extends State<MessageReactionRegion> {
  late ChatReactionKind? _selected;
  late Map<ChatReactionKind, int> _counts;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
    _counts = Map<ChatReactionKind, int>.of(widget.initialCounts);
  }

  @override
  void didUpdateWidget(covariant MessageReactionRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _selected = widget.initialSelected;
      _counts = Map<ChatReactionKind, int>.of(widget.initialCounts);
    }
  }

  Future<void> _handleLongPress(LongPressStartDetails details) async {
    final picked = await MessageReactionPicker.show(
      context: context,
      globalPosition: details.globalPosition,
      selected: _selected,
    );
    if (!mounted || picked == null) return;

    final previousSelected = _selected;
    final previousCounts = Map<ChatReactionKind, int>.of(_counts);
    ChatReactionKind? next;
    final updated = Map<ChatReactionKind, int>.of(_counts);

    if (previousSelected == picked) {
      next = null;
      final count = updated[picked] ?? 0;
      if (count <= 1) {
        updated.remove(picked);
      } else {
        updated[picked] = count - 1;
      }
    } else {
      next = picked;
      if (previousSelected != null) {
        final oldCount = updated[previousSelected] ?? 0;
        if (oldCount <= 1) {
          updated.remove(previousSelected);
        } else {
          updated[previousSelected] = oldCount - 1;
        }
      }
      updated[picked] = (updated[picked] ?? 0) + 1;
    }

    setState(() {
      _selected = next;
      _counts = updated;
    });

    try {
      await widget.onChanged?.call(widget.messageId, next, updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selected = previousSelected;
        _counts = previousCounts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPressStart: _handleLongPress,
      child: Column(
        crossAxisAlignment: widget.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          widget.child,
          if (_counts.values.any((count) => count > 0)) ...<Widget>[
            const SizedBox(height: 4),
            MessageReactionSummary(
              counts: _counts,
              alignment: widget.isMine
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReactionCompleter {
  final Completer<ChatReactionKind?> _completer =
      Completer<ChatReactionKind?>();
  void Function()? onComplete;

  Future<ChatReactionKind?> get future => _completer.future;

  void complete(ChatReactionKind? value) {
    if (_completer.isCompleted) return;
    onComplete?.call();
    _completer.complete(value);
  }
}
