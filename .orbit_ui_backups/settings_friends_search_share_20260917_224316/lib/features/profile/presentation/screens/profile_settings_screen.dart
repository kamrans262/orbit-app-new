import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../domain/models/profile_models.dart';
import '../../../more_menu/presentation/screens/more_menu_screen.dart';
import '../widgets/profile_summary_header.dart';
import '../widgets/settings_list_item.dart';
import '../../../circles/presentation/screens/circle_setting_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_screen.dart';
import 'blocked_users_screen.dart';
import 'privacy_setting_screen.dart';
import '../../../../core/popups/orbit_popup_variants.dart';

abstract final class SettingsKeys {
  static const scrollView = Key('settings_scroll_view');
  static const profileHeader = Key('settings_profile_header');
  static const listCard = Key('settings_list_card');
  static const bottomNavigation = Key('settings_bottom_navigation');

  static Key item(String id) => Key('settings_item_$id');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.profile,
    required this.onTabSelected,
    required this.onAddPressed,
    this.onEditProfilePressed,
    this.onMyCirclesPressed,
    this.onFriendsPressed,
    this.onNotificationPressed,
    this.onBlockedUsersPressed,
    this.onPrivacySettingsPressed,
    this.onLocationSettingsPressed,
    this.onSosSettingsPressed,
    this.onMoreMenuPressed,
    super.key,
  });

  static const Color _pageBackground = Color(0xFFF9F9F9);
  static const double _cardHorizontalInset = 14;
  static const double _cardHorizontalPadding = 18;
  static const double _cardVerticalPadding = 20;
  static const double _itemGap = 10;

  static const LinearGradient _fadeToPageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x00F9F9F9),
      Color(0x00F9F9F9),
      Color(0xD9F9F9F9),
      _pageBackground,
    ],
    stops: <double>[0, 0.58, 0.9, 1],
  );

  final ProfileData profile;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final VoidCallback? onEditProfilePressed;
  final VoidCallback? onMyCirclesPressed;
  final VoidCallback? onFriendsPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onBlockedUsersPressed;
  final VoidCallback? onPrivacySettingsPressed;

  /// Kept for source compatibility with earlier SettingsScreen callers.
  /// The refreshed Figma no longer renders Location Settings.
  final VoidCallback? onLocationSettingsPressed;

  final VoidCallback? onSosSettingsPressed;
  final VoidCallback? onMoreMenuPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: _pageBackground,
        bottomNavigationBar: AppBottomNavigationBar(
          key: SettingsKeys.bottomNavigation,
          selectedIndex: 3,
          onTabSelected: (index) => _handleTabSelection(context, index),
          onAddPressed: () => _handleAddPressed(context),
        ),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              final safeTop = MediaQuery.paddingOf(context).top;

              // On the 390 x 866 Figma reference this places the card at
              // approximately y=326 while still staying safe on compact phones.
              final referenceHeaderExtent = viewportHeight * 0.41;
              final compactMinimumExtent = safeTop + 278;
              final headerExtent = referenceHeaderExtent > compactMinimumExtent
                  ? referenceHeaderExtent
                  : compactMinimumExtent;

              // The gradient/fade reaches the light page background below the
              // profile statistics instead of ending abruptly behind the card.
              final referenceGradientHeight = viewportHeight * 0.57;
              final minimumGradientHeight = headerExtent + 102;
              final gradientHeight =
                  referenceGradientHeight > minimumGradientHeight
                  ? referenceGradientHeight
                  : minimumGradientHeight;

              return Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: gradientHeight,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: ProfileSummaryHeader.profileGradient,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _fadeToPageBackground,
                        ),
                      ),
                    ),
                  ),
                  CustomScrollView(
                    key: SettingsKeys.scrollView,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: ProfileSummaryHeader(
                          key: SettingsKeys.profileHeader,
                          profile: profile,
                          height: headerExtent,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _cardHorizontalInset,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _SettingsCard(
                            onEditProfilePressed: () => _handleDestination(
                              context,
                              label: 'Edit Profile',
                              override: onEditProfilePressed,
                            ),
                            onMyCirclesPressed: () => _handleDestination(
                              context,
                              label: 'My Circles',
                              override: onMyCirclesPressed,
                            ),
                            onFriendsPressed: () => _handleDestination(
                              context,
                              label: 'Friends',
                              override: onFriendsPressed,
                            ),
                            onNotificationPressed: () => _handleDestination(
                              context,
                              label: 'Notification',
                              override: onNotificationPressed,
                            ),
                            onBlockedUsersPressed: () => _handleDestination(
                              context,
                              label: 'Blocked Users',
                              override: onBlockedUsersPressed,
                            ),
                            onPrivacySettingsPressed: () => _handleDestination(
                              context,
                              label: 'Privacy Settings',
                              override: onPrivacySettingsPressed,
                            ),
                            onSosSettingsPressed: () => _handleDestination(
                              context,
                              label: 'SOS Settings',
                              override: onSosSettingsPressed,
                            ),
                            onMoreMenuPressed: () => _handleDestination(
                              context,
                              label: 'More menu',
                              override: onMoreMenuPressed,
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleDestination(
    BuildContext context, {
    required String label,
    required VoidCallback? override,
  }) {
    if (override != null) {
      override();
      return;
    }
    if (label == 'Privacy Settings') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(
          builder: (_) => const PrivacySettingScreen(),
        ),
      );
      return;
    }
    if (label == 'Blocked Users') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(builder: (_) => const BlockedUsersScreen()),
      );
      return;
    }
    if (label == 'Notification') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(builder: (_) => const NotificationScreen()),
      );
      return;
    }
    if (label == 'Edit Profile') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(
          builder: (_) => EditProfileScreen(profile: profile),
        ),
      );
      return;
    }
    if (label == 'My Circles') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(builder: (_) => CircleSettingScreen.demo()),
      );
      return;
    }

    if (label == 'SOS Settings') {
      unawaited(
        showSosPopup(
          context,
          onTrustedContact: () {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trusted Contact selected.')),
            );
          },
          onTrustedUser: () {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trusted user selected.')),
            );
          },
        ),
      );
      return;
    }

    if (label == 'More menu') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(builder: (_) => const MoreMenuScreen()),
      );
      return;
    }

    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => _FutureSettingsDestination(title: label),
      ),
    );
  }

  void _handleTabSelection(BuildContext context, int index) {
    if (index == 3) {
      return;
    }

    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onTabSelected(index);
    });
  }

  void _handleAddPressed(BuildContext context) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onAddPressed();
    });
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.onEditProfilePressed,
    required this.onMyCirclesPressed,
    required this.onFriendsPressed,
    required this.onNotificationPressed,
    required this.onBlockedUsersPressed,
    required this.onPrivacySettingsPressed,
    required this.onSosSettingsPressed,
    required this.onMoreMenuPressed,
  });

  final VoidCallback onEditProfilePressed;
  final VoidCallback onMyCirclesPressed;
  final VoidCallback onFriendsPressed;
  final VoidCallback onNotificationPressed;
  final VoidCallback onBlockedUsersPressed;
  final VoidCallback onPrivacySettingsPressed;
  final VoidCallback onSosSettingsPressed;
  final VoidCallback onMoreMenuPressed;

  @override
  Widget build(BuildContext context) {
    final entries = <_SettingsEntry>[
      _SettingsEntry(
        id: 'edit_profile',
        icon: Icons.person_outline_rounded,
        iconWidget: const _EditProfileGlyph(),
        label: 'Edit Profile',
        onTap: onEditProfilePressed,
      ),
      _SettingsEntry(
        id: 'circles',
        icon: Icons.people_outline_rounded,
        label: 'My Circles',
        onTap: onMyCirclesPressed,
      ),
      _SettingsEntry(
        id: 'friends',
        icon: Icons.group_outlined,
        label: 'Friends',
        onTap: onFriendsPressed,
      ),
      _SettingsEntry(
        id: 'notification',
        icon: Icons.notifications_none_rounded,
        label: 'Notification',
        onTap: onNotificationPressed,
      ),
      _SettingsEntry(
        id: 'blocked',
        icon: Icons.person_off_outlined,
        label: 'Blocked Users',
        onTap: onBlockedUsersPressed,
      ),
      _SettingsEntry(
        id: 'privacy',
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy Settings',
        onTap: onPrivacySettingsPressed,
      ),
      _SettingsEntry(
        id: 'sos',
        icon: Icons.error_outline_rounded,
        label: 'SOS Settings',
        onTap: onSosSettingsPressed,
      ),
      _SettingsEntry(
        id: 'more_menu',
        icon: Icons.more_horiz_rounded,
        label: 'More menu',
        onTap: onMoreMenuPressed,
      ),
    ];

    return DecoratedBox(
      key: SettingsKeys.listCard,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 2),
            blurRadius: 7,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SettingsScreen._cardHorizontalPadding,
          vertical: SettingsScreen._cardVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var index = 0; index < entries.length; index++) ...<Widget>[
              SettingsListItem(
                key: SettingsKeys.item(entries[index].id),
                icon: entries[index].icon,
                iconWidget: entries[index].iconWidget,
                label: entries[index].label,
                onTap: entries[index].onTap,
              ),
              if (index != entries.length - 1)
                const SizedBox(height: SettingsScreen._itemGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsEntry {
  const _SettingsEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconWidget,
  });

  final String id;
  final IconData icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;
}

class _EditProfileGlyph extends StatelessWidget {
  const _EditProfileGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 1,
            top: 0,
            child: Icon(
              Icons.person_outline_rounded,
              size: 25,
              color: Color(0xFF7C3AED),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 1,
            child: Icon(
              Icons.edit_outlined,
              size: 14,
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureSettingsDestination extends StatelessWidget {
  const _FutureSettingsDestination({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0F1724),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const SizedBox.expand(),
    );
  }
}
