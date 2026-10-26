import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/nearby_person.dart';

class NearbyPersonTile extends StatelessWidget {
  const NearbyPersonTile({
    required this.person,
    required this.onAdd,
    this.tileKey,
    this.imageKey,
    this.addButtonKey,
    this.enabled = true,
    super.key,
  });

  static const double profileSize = 46;
  static const double imageToTextGap = 14;
  static const double nameToDistanceGap = 5;
  static const double addButtonSize = 36;
  static const double verticalPadding = 11.5;

  final NearbyPerson person;
  final VoidCallback onAdd;
  final Key? tileKey;
  final Key? imageKey;
  final Key? addButtonKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: tileKey,
      padding: const EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: SizedBox.square(
              key: imageKey,
              dimension: profileSize,
              child: person.imageAsset.isNotEmpty
                  ? Image.asset(
                      person.imageAsset,
                      width: profileSize,
                      height: profileSize,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    )
                  : const ColoredBox(
                      color: Color(0xFFF2EAFE),
                      child: Icon(Icons.person_outline_rounded,
                          color: Color(0xFF7C3AED), size: 26),
                    ),
            ),
          ),
          const SizedBox(width: imageToTextGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  person.name,
                  maxLines: 1,
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
                const SizedBox(height: nameToDistanceGap),
                Text(
                  person.distance,
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
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            enabled: enabled,
            label: 'Add ${person.name}',
            child: Material(
              key: addButtonKey,
              color: const Color(0xFF7C3AED),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onAdd : null,
                customBorder: const CircleBorder(),
                child: const SizedBox.square(
                  dimension: addButtonSize,
                  child: Icon(Icons.add_rounded, size: 26, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
