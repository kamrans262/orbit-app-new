import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../widgets/welcome_illustration.dart';

abstract final class WelcomeKeys {
  static const logo = Key('welcome_logo');
  static const getStartedButton = Key('welcome_get_started_button');
  static const logInButton = Key('welcome_log_in_button');
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onGetStarted,
    required this.onLogIn,
    super.key,
  });

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
            final imageWidth = (constraints.maxWidth - (horizontalPadding * 2))
                .clamp(260.0, 500.0)
                .toDouble();

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      compact ? AppSpacing.md : AppSpacing.xxxl,
                      horizontalPadding,
                      compact ? AppSpacing.lg : AppSpacing.xxl,
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
                        SizedBox(height: compact ? 34 : 58),
                        const _HeroHeading(),
                        SizedBox(height: compact ? 14 : AppSpacing.lg),
                        const Text(
                          'Orbit helps you stay\nconnected with the\npeople who matter most.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body,
                        ),
                        SizedBox(height: compact ? 16 : AppSpacing.lg),
                        SizedBox(
                          width: imageWidth,
                          child: const WelcomeIllustration(),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.md : AppSpacing.lg,
                        ),
                        SizedBox(
                          key: WelcomeKeys.getStartedButton,
                          child: AppPrimaryButton(
                            label: 'Get Started',
                            onPressed: onGetStarted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
        IgnorePointer(
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: AppColors.pinkGlow, blurRadius: 55),
              ],
            ),
          ),
        ),
        const Text(
          'Stay close.\nShare moments.\nLive together.',
          textAlign: TextAlign.center,
          style: AppTypography.largeHeading,
        ),
      ],
    );
  }
}
