import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/friend_details_models.dart';
import 'overlapping_avatar_stack.dart';

class CircleGroupCard extends StatelessWidget {
  const CircleGroupCard({
    required this.data,
    required this.onTap,
    required this.onFavoritePressed,
    super.key,
  });

  final CircleGroupData data;
  final VoidCallback onTap;
  final VoidCallback? onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final memberLabel = data.memberCount == 1
        ? '1 member'
        : '${data.memberCount} members';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 36,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      right: 32,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OverlappingAvatarStack(
                          avatars: data.memberAvatars,
                          memberCount: data.memberCount,
                          maxVisible: 3,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -7,
                      right: -7,
                      child: Semantics(
                        button: true,
                        label: data.isFavorite
                            ? 'Remove ${data.name} from favorites'
                            : 'Add ${data.name} to favorites',
                        child: IconButton(
                          onPressed: onFavoritePressed,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                          icon: Icon(
                            data.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: const Color(0xFFFF4757),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    data.name,
                    maxLines: 2,
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
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                memberLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: const <String>[
                    'Noto Color Emoji',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                  ],
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
