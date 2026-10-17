import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class NotificationsKeys {
  static const heading = Key('notifications_heading');
  static const body = Key('notifications_body');
  static const image = Key('notifications_image');
  static const allowButton = Key('notifications_allow_button');
  static const notNowButton = Key('notifications_not_now_button');
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    required this.onAllowNotification,
    required this.onNotNow,
    super.key,
  });

  static const double _headingToBodyGap = 10;
  static const double _bodyToImageGap = 66;

  final VoidCallback onAllowNotification;
  final VoidCallback onNotNow;

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
                      delegate: _NotificationsLayoutDelegate(
                        topPadding: compact ? 12 : 52,
                        horizontalPadding: horizontalPadding,
                        bodyToImageGap: _bodyToImageGap,
                      ),
                      children: <Widget>[
                        LayoutId(
                          id: _NotificationsSlot.header,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Stay In the loop',
                                key: NotificationsKeys.heading,
                                textAlign: TextAlign.center,
                                style: AppTypography.largeHeading,
                              ),
                              SizedBox(height: _headingToBodyGap),
                              Text(
                                'Turn on notifications so you\nnever miss what matters.',
                                key: NotificationsKeys.body,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        LayoutId(
                          id: _NotificationsSlot.image,
                          child: const _NotificationIllustration(),
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
                      primaryKey: NotificationsKeys.allowButton,
                      primaryLabel: 'Allow Notification',
                      onPrimaryPressed: onAllowNotification,
                      secondaryKey: NotificationsKeys.notNowButton,
                      secondaryLabel: 'Not Now',
                      onSecondaryPressed: onNotNow,
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

class _NotificationIllustration extends StatelessWidget {
  const _NotificationIllustration();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Orbit notification illustration',
      child: SizedBox.expand(
        key: NotificationsKeys.image,
        child: Image.asset(
          'assets/Notifcation.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

enum _NotificationsSlot { header, image }

class _NotificationsLayoutDelegate extends MultiChildLayoutDelegate {
  _NotificationsLayoutDelegate({
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
      _NotificationsSlot.header,
      BoxConstraints(maxWidth: headerWidth),
    );
    final headerX = (size.width - headerSize.width) / 2;
    final headerY = math.min(
      topPadding,
      math.max(0.0, size.height - headerSize.height),
    );
    positionChild(_NotificationsSlot.header, Offset(headerX, headerY));

    final imageTop = headerY + headerSize.height + bodyToImageGap;
    final imageHeight = math.max(0.0, size.height - imageTop);

    layoutChild(
      _NotificationsSlot.image,
      BoxConstraints.tightFor(width: size.width, height: imageHeight),
    );
    positionChild(_NotificationsSlot.image, Offset(0, imageTop));
  }

  @override
  bool shouldRelayout(covariant _NotificationsLayoutDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        horizontalPadding != oldDelegate.horizontalPadding ||
        bodyToImageGap != oldDelegate.bodyToImageGap;
  }
}
