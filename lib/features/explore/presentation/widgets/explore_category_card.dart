import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/explore_models.dart';

class ExploreCategoryCard extends StatelessWidget {
  const ExploreCategoryCard({
    required this.data,
    required this.onTap,
    super.key,
  });

  final ExploreCategoryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${data.title}, ${data.count}',
      child: Material(
        color: const Color(0xFFF1EFFB),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 28,
                      child: SvgPicture.asset(
                        data.iconAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${data.count}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontFamilyFallback: <String>[AppTypography.fontFamily],
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E9196),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontFamilyFallback: <String>[AppTypography.fontFamily],
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
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
