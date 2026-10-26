import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../domain/models/profile_models.dart';
import 'profile_media_image.dart';

/// Shared Profile/Settings identity + statistics header.
///
/// Keeping this as one widget prevents the Settings screen from drifting away
/// from the Profile screen when backend-driven profile data changes later.
class ProfileSummaryHeader extends StatelessWidget {
  const ProfileSummaryHeader({
    required this.profile,
    required this.height,
    this.horizontalPadding = 28,
    this.topPadding = 20,
    this.showSettingsButton = false,
    this.showStats = true,
    this.showBackButton = false,
    this.showInitialsForMissingAvatar = false,
    this.onBackPressed,
    this.onSettingsPressed,
    this.avatarKey,
    this.statsKey,
    this.settingsButtonKey,
    super.key,
  });

  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFED65C9), Color(0xFF7C3AED)],
  );

  static const LinearGradient fadeToWhiteGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
      Color(0xD9FFFFFF),
      Colors.white,
    ],
    stops: <double>[0, 0.58, 0.9, 1],
  );

  final ProfileData profile;
  final double height;
  final double horizontalPadding;
  final double topPadding;
  final bool showSettingsButton;
  final bool showStats;
  final bool showBackButton;
  final bool showInitialsForMissingAvatar;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSettingsPressed;
  final Key? avatarKey;
  final Key? statsKey;
  final Key? settingsButtonKey;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              safeTop + topPadding,
              horizontalPadding,
              0,
            ),
            child: Column(
              children: <Widget>[
                _ProfileAvatar(
                  key: avatarKey,
                  profile: profile,
                  initialsFallback: showInitialsForMissingAvatar,
                ),
                const SizedBox(height: 10),
                Text(
                  profile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.bio,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                if (showStats) ...<Widget>[
                  const SizedBox(height: 30),
                  _ProfileStats(
                    key: statsKey,
                    circleCount: profile.circleCount,
                    friendCount: profile.friendCount,
                    momentCount: profile.momentCount,
                  ),
                ],
              ],
            ),
          ),
          if (showBackButton)
            Positioned(
              top: safeTop + topPadding,
              left: horizontalPadding,
              child: AppCircularIconButton(
                semanticLabel: 'Back',
                onPressed: onBackPressed ??
                    () => Navigator.of(context).maybePop(),
                icon: Icons.chevron_left_rounded,
                size: 30,
                iconSize: 24,
                iconColor: Colors.black,
              ),
            ),
          if (showSettingsButton)
            Positioned(
              top: safeTop + topPadding,
              right: horizontalPadding,
              child: AppCircularIconButton(
                key: settingsButtonKey,
                onPressed: onSettingsPressed ?? () {},
                icon: Icons.settings_outlined,
                size: 30,
                iconSize: 17,
                iconColor: AppColors.primaryEnd,
                iconGradient: AppColors.primaryGradient,
                semanticLabel: 'Settings',
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    this.initialsFallback = false,
    super.key,
  });

  final ProfileData profile;
  final bool initialsFallback;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: 80,
        child: initialsFallback &&
                profile.imagePath == null &&
                profile.imageUrl == null &&
                profile.imageBytes == null
            ? ColoredBox(
                color: const Color(0xFFF2EAFE),
                child: Center(
                  child: Text(
                    profile.name.trim().isEmpty
                        ? '?' : profile.name.trim().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryEnd,
                    ),
                  ),
                ),
              )
            : ProfileMediaImage(
                assetPath: profile.imagePath,
                imageUrl: profile.imageUrl,
                bytes: profile.imageBytes,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                fallbackAspectRatio: 1,
              ),
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({
    required this.circleCount,
    required this.friendCount,
    required this.momentCount,
    super.key,
  });

  final int circleCount;
  final int friendCount;
  final int momentCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ProfileStat(label: 'Circle', value: circleCount),
        ),
        const _StatSeparator(),
        Expanded(
          child: _ProfileStat(label: 'Friends', value: friendCount),
        ),
        const _StatSeparator(),
        Expanded(
          child: _ProfileStat(label: 'Moments', value: momentCount),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: Color(0xE6FFFFFF),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            maxLines: 1,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: const <String>[
                'Noto Color Emoji',
                'Apple Color Emoji',
                'Segoe UI Emoji',
              ],
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatSeparator extends StatelessWidget {
  const _StatSeparator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 42,
      child: VerticalDivider(width: 1, thickness: 1, color: Color(0x42FFFFFF)),
    );
  }
}
