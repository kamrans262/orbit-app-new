import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class YourCircleKeys {
  static const heading = Key('your_circle_heading');
  static const body = Key('your_circle_body');
  static const image = Key('your_circle_image');
  static const nextButton = Key('your_circle_next_button');
}

class YourCircleScreen extends StatelessWidget {
  const YourCircleScreen({required this.onNext, super.key});

  static const double _headingToBodyGap = 10;
  static const double _bodyToImageGap = 66;

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
                      delegate: _YourCircleLayoutDelegate(
                        topPadding: compact ? 12 : 52,
                        horizontalPadding: horizontalPadding,
                        bodyToImageGap: _bodyToImageGap,
                      ),
                      children: const <Widget>[
                        LayoutId(
                          id: _YourCircleSlot.header,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Your Circle',
                                key: YourCircleKeys.heading,
                                textAlign: TextAlign.center,
                                style: AppTypography.largeHeading,
                              ),
                              SizedBox(height: _headingToBodyGap),
                              Text(
                                'The people who matter most, all in one place.',
                                key: YourCircleKeys.body,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        LayoutId(
                          id: _YourCircleSlot.image,
                          child: _YourCircleImage(),
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
                      primaryKey: YourCircleKeys.nextButton,
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

class _YourCircleImage extends StatelessWidget {
  const _YourCircleImage();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Your Orbit circle',
      child: SizedBox.expand(
        key: YourCircleKeys.image,
        child: Image.asset(
          'assets/your_circle.png',
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

enum _YourCircleSlot { header, image }

class _YourCircleLayoutDelegate extends MultiChildLayoutDelegate {
  const _YourCircleLayoutDelegate({
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
      _YourCircleSlot.header,
      BoxConstraints(maxWidth: headerWidth),
    );
    final headerX = (size.width - headerSize.width) / 2;
    final headerY = math.min(
      topPadding,
      math.max(0.0, size.height - headerSize.height),
    );
    positionChild(_YourCircleSlot.header, Offset(headerX, headerY));

    final imageTop = headerY + headerSize.height + bodyToImageGap;
    final imageHeight = math.max(0.0, size.height - imageTop);

    layoutChild(
      _YourCircleSlot.image,
      BoxConstraints.tightFor(width: size.width, height: imageHeight),
    );
    positionChild(_YourCircleSlot.image, Offset(0, imageTop));
  }

  @override
  bool shouldRelayout(covariant _YourCircleLayoutDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        horizontalPadding != oldDelegate.horizontalPadding ||
        bodyToImageGap != oldDelegate.bodyToImageGap;
  }
}
