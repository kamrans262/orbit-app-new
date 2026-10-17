import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class Welcome2Keys {
  static const heading = Key('welcome2_heading');
  static const body = Key('welcome2_body');
  static const map = Key('welcome2_map');
  static const nextButton = Key('welcome2_next_button');
}

class Welcome2Screen extends StatelessWidget {
  const Welcome2Screen({required this.onNext, super.key});

  static const double _headingToBodyGap = 20;
  static const double _bodyToImageGap = 20;

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final horizontalPadding = WelcomeLayoutMetrics.horizontalPadding(
              constraints.maxWidth,
            );
            final contentBottomInset = WelcomeLayoutMetrics.contentBottomInset(
              context,
            );

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  bottom: contentBottomInset,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          compact ? AppSpacing.xl : 52,
                          horizontalPadding,
                          0,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: WelcomeLayoutMetrics.maxContentWidth,
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Live. Share. Protect',
                                  key: Welcome2Keys.heading,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.largeHeading,
                                ),
                                SizedBox(height: _headingToBodyGap),
                                Text(
                                  "See where your people are in\nreal-time and know they're\nsafe.",
                                  key: Welcome2Keys.body,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: _bodyToImageGap),
                      Expanded(
                        child: SizedBox.expand(
                          key: Welcome2Keys.map,
                          child: Semantics(
                            image: true,
                            label: 'Orbit live location map',
                            child: Image.asset(
                              'assets/map.png',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: WelcomeLayoutMetrics.bottomSpacing,
                  child: Center(
                    child: WelcomeActionPanel(
                      primaryKey: Welcome2Keys.nextButton,
                      primaryLabel: 'Next',
                      onPrimaryPressed: onNext,
                      reserveSecondarySlot: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
