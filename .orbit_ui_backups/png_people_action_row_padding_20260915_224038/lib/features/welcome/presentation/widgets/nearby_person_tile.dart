import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
              child: SvgPicture.asset(person.imageAsset, fit: BoxFit.cover),
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
            label: 'Add ${person.name}',
            child: Material(
              key: addButtonKey,
              color: const Color(0xFF7C3AED),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onAdd,
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
