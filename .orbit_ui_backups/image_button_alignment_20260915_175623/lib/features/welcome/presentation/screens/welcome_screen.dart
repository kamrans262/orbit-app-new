import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_illustration.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class WelcomeKeys {
  static const logo = Key('welcome_logo');
  static const heading = Key('welcome_heading');
  static const body = Key('welcome_body');
  static const getStartedButton = Key('welcome_get_started_button');
  static const logInButton = Key('welcome_log_in_button');
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onGetStarted,
    required this.onLogIn,
    super.key,
  });

  static const double _logoToHeadingGap = 30;
  static const double _headingToBodyGap = 10;

  final VoidCallback onGetStarted;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            final compact = viewportHeight < 720;
            final horizontalPadding = WelcomeLayoutMetrics.horizontalPadding(
              constraints.maxWidth,
            );
            final logoSize = compact ? 74.0 : 86.0;
            final actionAreaHeight = WelcomeLayoutMetrics.actionAreaHeight(
              context,
            );

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: actionAreaHeight + (compact ? 12 : 20),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: WelcomeLayoutMetrics.maxContentWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                compact ? AppSpacing.md : AppSpacing.xxxl,
                                horizontalPadding,
                                0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Semantics(
                                    image: true,
                                    label: 'Orbit logo',
                                    child: Image.asset(
                                      'assets/logo.png',
                                      key: WelcomeKeys.logo,
                                      width: logoSize,
                                      height: logoSize,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return SizedBox.square(
                                              dimension: logoSize,
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(height: _logoToHeadingGap),
                                  const _HeroHeading(),
                                  const SizedBox(height: _headingToBodyGap),
                                  const Text(
                                    'Orbit helps you stay\nconnected with the\npeople who matter most.',
                                    key: WelcomeKeys.body,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: compact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            const WelcomeIllustration(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: WelcomeLayoutMetrics.bottomSpacing,
                  child: Center(
                    child: WelcomeActionPanel(
                      primaryKey: WelcomeKeys.getStartedButton,
                      primaryLabel: 'Get Started',
                      onPrimaryPressed: onGetStarted,
                      secondaryKey: WelcomeKeys.logInButton,
                      secondaryLabel: 'Log In',
                      onSecondaryPressed: onLogIn,
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

class _HeroHeading extends StatelessWidget {
  const _HeroHeading();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        const Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: OverflowBox(
                minWidth: 200,
                maxWidth: 200,
                minHeight: 200,
                maxHeight: 200,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: AppColors.pinkGlow, blurRadius: 55),
                    ],
                  ),
                  child: SizedBox.square(dimension: 200),
                ),
              ),
            ),
          ),
        ),
        const Text(
          'Stay close.\nShare moments.\nLive together.',
          key: WelcomeKeys.heading,
          textAlign: TextAlign.center,
          style: AppTypography.largeHeading,
        ),
      ],
    );
  }
}
