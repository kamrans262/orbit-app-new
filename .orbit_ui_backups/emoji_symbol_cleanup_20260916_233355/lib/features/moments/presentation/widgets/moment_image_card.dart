import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_media_image.dart';
import 'moment_profile_avatar.dart';
import '../../../../core/widgets/app_emoji_safe_text.dart';

class MomentImageCard extends StatelessWidget {
  const MomentImageCard({
    required this.data,
    required this.isLiked,
    required this.isBookmarked,
    required this.onLikePressed,
    required this.onCommentPressed,
    required this.onBookmarkPressed,
    required this.onSharePressed,
    super.key,
  });

  final MomentImageFeedItem data;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback onLikePressed;
  final VoidCallback onCommentPressed;
  final VoidCallback onBookmarkPressed;
  final VoidCallback onSharePressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.06,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  MomentMediaImage(path: data.imagePath, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: <double>[0, 0.34, 0.62, 1],
                        colors: <Color>[
                          Color(0x8A000000),
                          Color(0x18000000),
                          Color(0x22000000),
                          Color(0xA6000000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15,
                    left: 12,
                    right: 12,
                    child: _ImageCardHeader(
                      data: data,
                      onSharePressed: onSharePressed,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 15,
                    child: _ImageCardCaption(data: data),
                  ),
                ],
              ),
            ),
          ),
          _EngagementBar(
            likeCount: data.likeCount,
            commentCount: data.commentCount,
            isLiked: isLiked,
            isBookmarked: isBookmarked,
            onLikePressed: onLikePressed,
            onCommentPressed: onCommentPressed,
            onBookmarkPressed: onBookmarkPressed,
          ),
        ],
      ),
    );
  }
}

class _ImageCardHeader extends StatelessWidget {
  const _ImageCardHeader({required this.data, required this.onSharePressed});

  final MomentImageFeedItem data;
  final VoidCallback onSharePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        MomentProfileAvatar(
          author: data.author,
          size: 32,
          borderColor: Colors.white,
          borderWidth: 2,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.author.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: const <String>[
                    'Noto Color Emoji',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                  ],
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                data.timeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: const <String>[
                    'Noto Color Emoji',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                  ],
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFECECF1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Share moment',
          onPressed: onSharePressed,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          icon: SvgPicture.asset(
            'assets/icons/send.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ],
    );
  }
}

class _ImageCardCaption extends StatelessWidget {
  const _ImageCardCaption({required this.data});

  final MomentImageFeedItem data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppEmojiSafeAppEmojiSafeText(
          data.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (data.location.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                size: 13,
                color: Color(0xFFF2F2F6),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  data.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFF2F2F6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EngagementBar extends StatelessWidget {
  const _EngagementBar({
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.onLikePressed,
    required this.onCommentPressed,
    required this.onBookmarkPressed,
  });

  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback onLikePressed;
  final VoidCallback onCommentPressed;
  final VoidCallback onBookmarkPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          _EngagementAction(
            semanticLabel: isLiked ? 'Unlike moment' : 'Like moment',
            icon: isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: isLiked
                ? const Color(0xFFFF4757)
                : const Color(0xFF8A85A8),
            value: likeCount,
            onTap: onLikePressed,
          ),
          const SizedBox(width: 16),
          _EngagementAction(
            semanticLabel: 'Comment on moment',
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF8A85A8),
            value: commentCount,
            onTap: onCommentPressed,
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: isBookmarked ? 'Remove bookmark' : 'Bookmark moment',
            child: InkResponse(
              onTap: onBookmarkPressed,
              radius: 24,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: isBookmarked
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF8A85A8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementAction extends StatelessWidget {
  const _EngagementAction({
    required this.semanticLabel,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final Color iconColor;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 2),
            Text(
              _compactCount(value),
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8A85A8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactCount(int count) {
    if (count < 1000) {
      return count.toString();
    }
    if (count < 1000000) {
      final value = count / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
    }
    final value = count / 1000000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}m';
  }
}
