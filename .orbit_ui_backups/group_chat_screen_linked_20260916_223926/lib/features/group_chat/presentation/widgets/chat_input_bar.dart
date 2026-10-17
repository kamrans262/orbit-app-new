import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';

abstract final class ChatInputKeys {
  static const plusButton = Key('group_chat_plus_button');
  static const textField = Key('group_chat_text_field');
  static const sendButton = Key('group_chat_send_button');
}

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_syncTextState);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncTextState);
      widget.controller.addListener(_syncTextState);
      _syncTextState();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTextState);
    super.dispose();
  }

  void _syncTextState() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText && mounted) {
      setState(() => _hasText = next);
    }
  }

  Future<void> _openPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Emoji & stickers',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <String>['❤️', '😂', '🔥', '👏', '👍', '🎉']
                    .map(
                      (emoji) => InkWell(
                        onTap: () => Navigator.of(context).pop(emoji),
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sticker selector is ready for the future sticker library.',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final selection = widget.controller.selection;
    final text = widget.controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    widget.controller.value = TextEditingValue(
      text: text.replaceRange(start, end, selected),
      selection: TextSelection.collapsed(offset: start + selected.length),
    );
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 17),
      decoration: const BoxDecoration(
        color: Color(0xFFF0EEEB),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Add emoji or sticker',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: ChatInputKeys.plusButton,
                onTap: _openPicker,
                customBorder: const CircleBorder(),
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.add_rounded,
                    size: 28,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 104),
              child: TextField(
                key: ChatInputKeys.textField,
                controller: widget.controller,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFF0F1724),
                ),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: _hasText,
            label: 'Send message',
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _hasText ? 1 : 0.42,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ChatInputKeys.sendButton,
                    onTap: _hasText ? widget.onSend : null,
                    customBorder: const CircleBorder(),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/send.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
