import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/group_chat_models.dart';
import 'chat_avatar.dart';
import 'chat_timestamp.dart';
import 'gradient_text.dart';

class ReceivedImageMessage extends StatelessWidget {
  const ReceivedImageMessage({
    required this.message,
    required this.onReactionChanged,
    super.key,
  });

  final GroupChatMessage message;
  final ValueChanged<ChatReactionState> onReactionChanged;

  @override
  Widget build(BuildContext context) {
    final maxCardWidth = MediaQuery.sizeOf(context).width * 0.76;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ChatAvatar(name: message.senderName, imagePath: message.senderAvatar),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        GradientText(
                          (message.text ?? '').trim().isEmpty
                              ? 'Here’s what I created:'
                              : message.text!.trim(),
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ImagePair(paths: message.images),
                        const SizedBox(height: 10),
                        _ReactionRow(
                          avatars: message.reactionAvatars,
                          state: message.reactionState,
                          onChanged: onReactionChanged,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                ChatTimestamp(message.timestamp),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagePair extends StatelessWidget {
  const _ImagePair({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final first = paths.isNotEmpty ? paths.first : null;
    final second = paths.length > 1 ? paths[1] : null;
    return AspectRatio(
      aspectRatio: 1.9,
      child: Row(
        children: <Widget>[
          Expanded(child: _MessageImage(path: first)),
          const SizedBox(width: 4),
          Expanded(child: _MessageImage(path: second)),
        ],
      ),
    );
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final safePath = path?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: safePath == null || safePath.isEmpty
          ? const _ImageFallback()
          : Image.asset(
              safePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _ImageFallback(),
            ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF2EAFE),
      child: Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF7C3AED)),
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.avatars,
    required this.state,
    required this.onChanged,
  });

  final List<String> avatars;
  final ChatReactionState state;
  final ValueChanged<ChatReactionState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _ReactingAvatars(paths: avatars)),
        const SizedBox(width: 8),
        _ReactionButton(
          semanticLabel: 'Like',
          assetPath: 'assets/icons/like.svg',
          isSelected: state == ChatReactionState.liked,
          onTap: () => onChanged(
            state == ChatReactionState.liked
                ? ChatReactionState.none
                : ChatReactionState.liked,
          ),
        ),
        const SizedBox(width: 8),
        _ReactionButton(
          semanticLabel: 'Dislike',
          assetPath: 'assets/icons/dislike.svg',
          isSelected: state == ChatReactionState.disliked,
          onTap: () => onChanged(
            state == ChatReactionState.disliked
                ? ChatReactionState.none
                : ChatReactionState.disliked,
          ),
        ),
      ],
    );
  }
}

class _ReactingAvatars extends StatelessWidget {
  const _ReactingAvatars({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final visible = paths.take(3).toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox(height: 24);
    }
    const size = 24.0;
    const step = 17.0;
    return SizedBox(
      height: size,
      width: size + ((visible.length - 1) * step),
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * step,
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    visible[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Color(0xFFE9DDFD)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.semanticLabel,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  final String semanticLabel;
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFF7C3AED)
        : const Color(0xFF94A3B8);
    return Semantics(
      button: true,
      label: semanticLabel,
      selected: isSelected,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox.square(
          dimension: 32,
          child: Center(
            child: isSelected
                ? Icon(
                    semanticLabel == 'Like'
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_down_rounded,
                    size: 20,
                    color: color,
                    semanticLabel: semanticLabel,
                  )
                : SvgPicture.asset(
                    assetPath,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
          ),
        ),
      ),
    );
  }
}
