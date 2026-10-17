import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';

abstract final class DirectChatInputKeys {
  static const attachment = Key('direct_chat_attachment_button');
  static const field = Key('direct_chat_text_field');
  static const location = Key('direct_chat_location_button');
  static const send = Key('direct_chat_send_button');
}

class DirectChatInputBar extends StatefulWidget {
  const DirectChatInputBar({
    required this.personName,
    required this.controller,
    required this.focusNode,
    required this.onAttachment,
    required this.onLocation,
    required this.onSend,
    super.key,
  });

  final String personName;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAttachment;
  final VoidCallback onLocation;
  final VoidCallback onSend;

  @override
  State<DirectChatInputBar> createState() => _DirectChatInputBarState();
}

class _DirectChatInputBarState extends State<DirectChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant DirectChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText && mounted) setState(() => _hasText = next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(top: BorderSide(color: Color(0xFFEAE7ED))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _RoundActionButton(
            key: DirectChatInputKeys.attachment,
            semanticLabel: 'Attachments',
            onPressed: widget.onAttachment,
            backgroundColor: Colors.transparent,
            borderColor: const Color(0xFF8B95A1),
            child: const Icon(
              Icons.add_rounded,
              size: 25,
              color: Color(0xFF8B95A1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 96),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E9FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                key: DirectChatInputKeys.field,
                controller: widget.controller,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFF0F1724),
                ),
                decoration: InputDecoration(
                  hintText: 'Message ${widget.personName}...',
                  hintStyle: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    color: Color(0xFF9AA4B2),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundActionButton(
            key: DirectChatInputKeys.location,
            semanticLabel: 'Share location',
            onPressed: widget.onLocation,
            backgroundColor: Colors.transparent,
            child: SvgPicture.asset(
              'assets/icons/location.svg',
              width: 23,
              height: 23,
              colorFilter: const ColorFilter.mode(
                Color(0xFF7C3AED),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _hasText ? 1 : 0.55,
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
                  key: DirectChatInputKeys.send,
                  onTap: _hasText ? widget.onSend : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: 46,
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
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
    this.borderColor,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color? borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: backgroundColor,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(dimension: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}
