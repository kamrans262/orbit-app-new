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
    this.onPickSingleImage,
    this.onPickMultipleImages,
    this.onPickSticker,
    this.onRecordVoice,
    this.onPickVideo,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback? onPickSingleImage;
  final VoidCallback? onPickMultipleImages;
  final VoidCallback? onPickSticker;
  final VoidCallback? onRecordVoice;
  final VoidCallback? onPickVideo;
  final bool enabled;

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
    if (next != _hasText && mounted) setState(() => _hasText = next);
  }

  Future<void> _openPicker() async {
    if(!widget.enabled)return;
    final choice = await showModalBottomSheet<_GroupAttachmentChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _AttachmentTile(
                icon: Icons.image_outlined,
                label: 'Single image',
                onTap: widget.onPickSingleImage == null
                    ? null
                    : () => Navigator.pop(
                        sheetContext,
                        _GroupAttachmentChoice.singleImage,
                      ),
              ),
              _AttachmentTile(
                icon: Icons.photo_library_outlined,
                label: 'Multiple images',
                onTap: widget.onPickMultipleImages == null
                    ? null
                    : () => Navigator.pop(
                        sheetContext,
                        _GroupAttachmentChoice.multipleImages,
                      ),
              ),
              _AttachmentTile(
                icon: Icons.sentiment_satisfied_alt_rounded,
                label: 'Emoji / sticker',
                onTap: widget.onPickSticker == null
                    ? null
                    : () => Navigator.pop(
                        sheetContext,
                        _GroupAttachmentChoice.sticker,
                      ),
              ),
              _AttachmentTile(
                icon:Icons.videocam_outlined,label:'Video message',
                onTap:widget.onPickVideo==null?null:()=>
                  Navigator.pop(sheetContext,_GroupAttachmentChoice.video),
              ),
              _AttachmentTile(
                icon:Icons.mic_none_rounded,
                label:'Voice message',
                onTap:widget.onRecordVoice==null?null:()=>
                  Navigator.pop(sheetContext,_GroupAttachmentChoice.voice),
              ),
              const _AttachmentTile(
                icon: Icons.attach_file_rounded,
                label: 'Files (coming next)',
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _GroupAttachmentChoice.singleImage:
        widget.onPickSingleImage?.call();
        break;
      case _GroupAttachmentChoice.multipleImages:
        widget.onPickMultipleImages?.call();
        break;
      case _GroupAttachmentChoice.sticker:
        widget.onPickSticker?.call();
        break;
      case _GroupAttachmentChoice.voice:
        widget.onRecordVoice?.call();
        break;
      case _GroupAttachmentChoice.video:
        widget.onPickVideo?.call();
        break;
    }
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
            label: 'Add attachment',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: ChatInputKeys.plusButton,
                onTap: widget.enabled ? _openPicker : null,
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
                enabled: widget.enabled,
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
                    onTap: _hasText && widget.enabled ? widget.onSend : null,
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

enum _GroupAttachmentChoice { singleImage, multipleImages, sticker, voice, video }

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x1FA576F6),
        ),
        child: Icon(icon, color: const Color(0xFF7C3AED)),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F1724),
        ),
      ),
      onTap: onTap,
    );
  }
}
