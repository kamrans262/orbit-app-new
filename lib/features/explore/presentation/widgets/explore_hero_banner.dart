import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import 'explore_media_image.dart';

class ExploreHeroBanner extends StatelessWidget {
  const ExploreHeroBanner({
    required this.imagePath,
    super.key,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final rawHeight = width / (335 / 140);
        final height = rawHeight.clamp(132.0, 160.0).toDouble();
        final compact = width < 320;

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Color(0xFF3A2080),
                    Color(0xFF5A30C0),
                    Color(0xFF7C5CFC),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned(
                    right: -2,
                    bottom: 0,
                    width: width * (compact ? 0.54 : 0.58),
                    height: height,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: ExploreMediaImage(
                        path: imagePath,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.people_alt_outlined,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: width * (compact ? 0.48 : 0.51),
                        ),
                        child: Text(
                          'Meet people.\nDo more\ntogether.',
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontFamilyFallback: <String>[AppTypography.fontFamily],
                            fontSize: 22,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
