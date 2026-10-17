import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class ShareLocationKeys {
  static const heading = Key('share_location_heading');
  static const body = Key('share_location_body');
  static const image = Key('share_location_image');
  static const permissionCard = Key('share_location_permission_card');
  static const allowAlways = Key('share_location_allow_always');
  static const allowWhileUsing = Key('share_location_allow_while_using');
  static const notNow = Key('share_location_not_now');
}

class ShareLocationScreen extends StatelessWidget {
  const ShareLocationScreen({
    required this.onAllowAlways,
    required this.onAllowWhileUsing,
    required this.onNotNow,
    super.key,
  });

  static const double _headingToBodyGap = 10;
  static const double _bodyToImageGap = 20;
  static const double _permissionBottomSpacing = 40;

  final VoidCallback onAllowAlways;
  final VoidCallback onAllowWhileUsing;
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

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: compact ? 12 : 52),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: WelcomeLayoutMetrics.maxContentWidth,
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Share Location',
                                key: ShareLocationKeys.heading,
                                textAlign: TextAlign.center,
                                style: AppTypography.largeHeading,
                              ),
                              SizedBox(height: _headingToBodyGap),
                              Text(
                                'Orbit uses your location to help\ntrusted people feel closer and\nsafer.',
                                key: ShareLocationKeys.body,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: _bodyToImageGap),
                      const Expanded(child: _ShareLocationMap()),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: _permissionBottomSpacing,
                  child: Center(
                    child: _LocationPermissionCard(
                      onAllowAlways: onAllowAlways,
                      onAllowWhileUsing: onAllowWhileUsing,
                      onNotNow: onNotNow,
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

class _ShareLocationMap extends StatelessWidget {
  const _ShareLocationMap();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Orbit live location map',
      child: SizedBox.expand(
        key: ShareLocationKeys.image,
        child: Image.asset(
          'assets/map.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _LocationPermissionCard extends StatelessWidget {
  const _LocationPermissionCard({
    required this.onAllowAlways,
    required this.onAllowWhileUsing,
    required this.onNotNow,
  });

  static const double _referenceWidth = 347;
  static const double _height = 256;
  static const double _radius = 30;
  static const double _iconSize = 44;
  static const double _rowHorizontalPadding = 24;
  static const double _iconToLabelGap = 16;

  static const Color _iconBackground = Color(0xFFF3E8FF);
  static const Color _iconColor = Color(0xFFB447E6);
  static const Color _dividerColor = Color(0xFFEDEDED);
  static const Color _shadowColor = Color(0x1A000000);

  final VoidCallback onAllowAlways;
  final VoidCallback onAllowWhileUsing;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _referenceWidth),
      child: Container(
        key: ShareLocationKeys.permissionCard,
        width: double.infinity,
        height: _height,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _shadowColor,
              offset: Offset.zero,
              blurRadius: 2,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _PermissionOption(
                key: ShareLocationKeys.allowAlways,
                icon: Icons.location_on_rounded,
                label: 'Allow Always',
                onTap: onAllowAlways,
              ),
            ),
            const _PermissionDivider(),
            Expanded(
              child: _PermissionOption(
                key: ShareLocationKeys.allowWhileUsing,
                icon: Icons.phone_android_rounded,
                label: 'Allow While Using App',
                onTap: onAllowWhileUsing,
              ),
            ),
            const _PermissionDivider(),
            Expanded(
              child: _PermissionOption(
                key: ShareLocationKeys.notNow,
                icon: Icons.close_rounded,
                label: 'Not Now',
                onTap: onNotNow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionOption extends StatelessWidget {
  const _PermissionOption({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _LocationPermissionCard._rowHorizontalPadding,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: _LocationPermissionCard._iconSize,
                height: _LocationPermissionCard._iconSize,
                decoration: const BoxDecoration(
                  color: _LocationPermissionCard._iconBackground,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 26,
                  color: _LocationPermissionCard._iconColor,
                ),
              ),
              const SizedBox(width: _LocationPermissionCard._iconToLabelGap),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDivider extends StatelessWidget {
  const _PermissionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        height: 1,
        thickness: 1,
        color: _LocationPermissionCard._dividerColor,
      ),
    );
  }
}
