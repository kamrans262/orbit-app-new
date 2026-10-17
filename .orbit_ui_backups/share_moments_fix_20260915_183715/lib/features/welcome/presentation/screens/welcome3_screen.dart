import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class Welcome3Keys {
  static const heading = Key('welcome3_heading');
  static const body = Key('welcome3_body');
  static const image = Key('welcome3_image');
  static const nextButton = Key('welcome3_next_button');
}

class Welcome3Screen extends StatelessWidget {
  const Welcome3Screen({required this.onNext, super.key});

  static const double _headingToBodyGap = 10;
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
                                  'Share Moments',
                                  key: Welcome3Keys.heading,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.largeHeading,
                                ),
                                SizedBox(height: _headingToBodyGap),
                                Text(
                                  "Send instant snaps to your circles.\nShare what's happening right now.",
                                  key: Welcome3Keys.body,
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
                          key: Welcome3Keys.image,
                          child: Semantics(
                            image: true,
                            label: 'Friends sharing moments in Orbit',
                            child: Image.asset(
                              'assets/moments.png',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
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
                      primaryKey: Welcome3Keys.nextButton,
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
