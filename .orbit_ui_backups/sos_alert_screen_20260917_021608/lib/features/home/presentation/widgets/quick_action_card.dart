import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../explore/presentation/screens/explore_screen.dart';

import '../../../ping/presentation/screens/ping_screen.dart';
import '../../../moments/presentation/screens/moments_screen.dart';

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.data,
    required this.onTap,
    this.width = 78,
    super.key,
  });

  final QuickActionData data;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 90,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1A000000), blurRadius: 2),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (data.id == 'ping') {
                Navigator.of(context).push(
                  AppFadeSlidePageRoute<void>(
                    builder: (_) => PingScreen.demo(),
                  ),
                );
                return;
              }
              if (data.id == 'moment') {
                Navigator.of(context).push(
                  AppFadeSlidePageRoute<void>(
                    builder: (_) => MomentsScreen.demo(),
                  ),
                );
                return;
              }
              if (data.id == 'explore') {
                Navigator.of(context).push(
                  AppFadeSlidePageRoute<void>(
                    builder: (_) => ExploreScreen.demo(),
                  ),
                );
                return;
              }
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.iconBackground,
                    ),
                    alignment: Alignment.center,
                    child: Icon(data.icon, size: 22, color: data.iconColor),
                  ),
                  const SizedBox(height: 13),
                  Flexible(
                    child: Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontFamilyFallback: const <String>[
                          'Noto Color Emoji',
                          'Apple Color Emoji',
                          'Segoe UI Emoji',
                        ],
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F1724),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
