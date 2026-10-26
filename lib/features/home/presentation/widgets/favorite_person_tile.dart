import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';
import 'home_media_image.dart';

class FavoritePersonTile extends StatelessWidget {
  const FavoritePersonTile({
    required this.data,
    required this.onTap,
    required this.onFavoritePressed,
    this.showFavoriteAction = true,
    this.favoriteEnabled = true,
    this.trailingAction,
    super.key,
  });

  final FavoritePersonData data;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;
  final bool showFavoriteAction;
  final bool favoriteEnabled;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                HomeAvatar(
                  imagePath: data.imagePath,
                  name: data.name,
                  size: 46,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
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
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: const <String>[
                            'Noto Color Emoji',
                            'Apple Color Emoji',
                            'Segoe UI Emoji',
                          ],
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailingAction != null) trailingAction!,
                if (showFavoriteAction) Semantics(
                  button: true,
                  enabled: favoriteEnabled,
                  label: data.isFavorite
                      ? 'Remove ${data.name} from favorites'
                      : 'Add ${data.name} to favorites',
                  child: IconButton(
                    onPressed: favoriteEnabled ? onFavoritePressed : null,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      data.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: const Color(0xFFFF4757),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
