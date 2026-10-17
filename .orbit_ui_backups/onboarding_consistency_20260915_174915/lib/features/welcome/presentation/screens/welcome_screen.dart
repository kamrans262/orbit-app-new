import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../widgets/welcome_illustration.dart';

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
  static const double _buttonGap = 10;
  static const double _maxContentWidth = 560;

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
            final horizontalPadding = constraints.maxWidth < 360 ? 18.0 : 24.0;
            final logoSize = compact ? 74.0 : 86.0;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
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
                                errorBuilder: (context, error, stackTrace) {
                                  return SizedBox.square(dimension: logoSize);
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
                      SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                      const WelcomeIllustration(),
                      // SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              key: WelcomeKeys.getStartedButton,
                              child: AppPrimaryButton(
                                label: 'Get Started',
                                onPressed: onGetStarted,
                              ),
                            ),
                            const SizedBox(height: _buttonGap),
                            SizedBox(
                              key: WelcomeKeys.logInButton,
                              child: AppSecondaryButton(
                                label: 'Log In',
                                onPressed: onLogIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: compact ? AppSpacing.lg : AppSpacing.xxl,
                      ),
                    ],
                  ),
                ),
              ),
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
