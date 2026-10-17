import 'dart:math' as math;

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
            final compact = constraints.maxHeight < 720;
            final horizontalPadding = WelcomeLayoutMetrics.horizontalPadding(
              constraints.maxWidth,
            );
            final logoSize = compact ? 74.0 : 86.0;
            final contentBottomInset = WelcomeLayoutMetrics.contentBottomInset(
              context,
            );

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  bottom: contentBottomInset,
                  child: ClipRect(
                    child: CustomMultiChildLayout(
                      delegate: _WelcomeLayoutDelegate(
                        topPadding: compact ? AppSpacing.md : AppSpacing.xxxl,
                        horizontalPadding: horizontalPadding,
                        headerToImageGap: compact
                            ? AppSpacing.md
                            : AppSpacing.lg,
                      ),
                      children: <Widget>[
                        LayoutId(
                          id: _WelcomeSlot.header,
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
                        LayoutId(
                          id: _WelcomeSlot.image,
                          child: const WelcomeIllustration(),
                        ),
                      ],
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

enum _WelcomeSlot { header, image }

class _WelcomeLayoutDelegate extends MultiChildLayoutDelegate {
  _WelcomeLayoutDelegate({
    required this.topPadding,
    required this.horizontalPadding,
    required this.headerToImageGap,
  });

  final double topPadding;
  final double horizontalPadding;
  final double headerToImageGap;

  @override
  void performLayout(Size size) {
    final availableHeaderWidth = math.max(
      0.0,
      size.width - (horizontalPadding * 2),
    );
    final headerWidth = math.min(
      availableHeaderWidth,
      WelcomeLayoutMetrics.maxContentWidth,
    );

    final headerSize = layoutChild(
      _WelcomeSlot.header,
      BoxConstraints(maxWidth: headerWidth),
    );

    // Keep the requested internal spacing unchanged. On compact screens only
    // the whole header is shifted upward as needed so the image can still use
    // the remaining space without a RenderFlex overflow.
    final maxHeaderTop = math.max(
      0.0,
      size.height - headerSize.height - headerToImageGap,
    );
    final headerY = math.min(topPadding, maxHeaderTop);
    final headerX = (size.width - headerSize.width) / 2;
    positionChild(_WelcomeSlot.header, Offset(headerX, headerY));

    final imageTop = math.min(
      size.height,
      headerY + headerSize.height + headerToImageGap,
    );
    final imageHeight = math.max(0.0, size.height - imageTop);

    layoutChild(
      _WelcomeSlot.image,
      BoxConstraints.tightFor(width: size.width, height: imageHeight),
    );
    positionChild(_WelcomeSlot.image, Offset(0, imageTop));
  }

  @override
  bool shouldRelayout(covariant _WelcomeLayoutDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        horizontalPadding != oldDelegate.horizontalPadding ||
        headerToImageGap != oldDelegate.headerToImageGap;
  }
}
