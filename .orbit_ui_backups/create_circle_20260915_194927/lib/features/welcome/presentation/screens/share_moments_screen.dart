import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class ShareMomentsKeys {
  static const heading = Key('share_moments_heading');
  static const body = Key('share_moments_body');
  static const image = Key('share_moments_image');
  static const nextButton = Key('share_moments_next_button');
}

class ShareMomentsScreen extends StatelessWidget {
  const ShareMomentsScreen({required this.onNext, super.key});

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
                  child: ClipRect(
                    child: CustomMultiChildLayout(
                      delegate: _ShareMomentsLayoutDelegate(
                        topPadding: compact ? 12 : 52,
                        horizontalPadding: horizontalPadding,
                        bodyToImageGap: _bodyToImageGap,
                      ),
                      children: <Widget>[
                        LayoutId(
                          id: _ShareMomentsSlot.header,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Share Moments',
                                key: ShareMomentsKeys.heading,
                                textAlign: TextAlign.center,
                                style: AppTypography.largeHeading,
                              ),
                              SizedBox(height: _headingToBodyGap),
                              Text(
                                "Send instant snaps to your circles.\nShare what's happening right now.",
                                key: ShareMomentsKeys.body,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        LayoutId(
                          id: _ShareMomentsSlot.image,
                          child: _MomentsImage(),
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
                      primaryKey: ShareMomentsKeys.nextButton,
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

class _MomentsImage extends StatelessWidget {
  const _MomentsImage();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Friends sharing moments in Orbit',
      child: SizedBox.expand(
        key: ShareMomentsKeys.image,
        child: Image.asset(
          'assets/moments.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

enum _ShareMomentsSlot { header, image }

class _ShareMomentsLayoutDelegate extends MultiChildLayoutDelegate {
  _ShareMomentsLayoutDelegate({
    required this.topPadding,
    required this.horizontalPadding,
    required this.bodyToImageGap,
  });

  final double topPadding;
  final double horizontalPadding;
  final double bodyToImageGap;

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
      _ShareMomentsSlot.header,
      BoxConstraints(maxWidth: headerWidth),
    );
    final headerX = (size.width - headerSize.width) / 2;
    final headerY = math.min(
      topPadding,
      math.max(0.0, size.height - headerSize.height),
    );
    positionChild(_ShareMomentsSlot.header, Offset(headerX, headerY));

    final imageTop = headerY + headerSize.height + bodyToImageGap;
    final imageHeight = math.max(0.0, size.height - imageTop);

    layoutChild(
      _ShareMomentsSlot.image,
      BoxConstraints.tightFor(width: size.width, height: imageHeight),
    );
    positionChild(_ShareMomentsSlot.image, Offset(0, imageTop));
  }

  @override
  bool shouldRelayout(covariant _ShareMomentsLayoutDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        horizontalPadding != oldDelegate.horizontalPadding ||
        bodyToImageGap != oldDelegate.bodyToImageGap;
  }
}
