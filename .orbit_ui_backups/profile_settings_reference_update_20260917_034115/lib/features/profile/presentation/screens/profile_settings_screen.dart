import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../domain/models/profile_models.dart';
import '../widgets/profile_summary_header.dart';
import '../widgets/settings_list_item.dart';
import '../../../circles/presentation/screens/circle_setting_screen.dart';
import '../../../more_menu/presentation/screens/more_menu_screen.dart';

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
    this.onMyCirclesPressed,
    this.onFriendsPressed,
    this.onBlockedUsersPressed,
    this.onPrivacySettingsPressed,
    this.onLocationSettingsPressed,
    this.onSosSettingsPressed,
    super.key,
  });

  final ProfileData profile;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final VoidCallback? onMyCirclesPressed;
  final VoidCallback? onFriendsPressed;
  final VoidCallback? onBlockedUsersPressed;
  final VoidCallback? onPrivacySettingsPressed;
  final VoidCallback? onLocationSettingsPressed;
  final VoidCallback? onSosSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.white,
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
              final referenceHeaderExtent = viewportHeight * 0.38;
              final compactMinimumExtent = safeTop + 278;
              final headerExtent = referenceHeaderExtent > compactMinimumExtent
                  ? referenceHeaderExtent
                  : compactMinimumExtent;
              final referenceGradientHeight = viewportHeight * 0.54;
              final gradientHeight = referenceGradientHeight > headerExtent + 96
                  ? referenceGradientHeight
                  : headerExtent + 96;

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
                          gradient: ProfileSummaryHeader.fadeToWhiteGradient,
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
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        sliver: SliverToBoxAdapter(
                          child: _SettingsCard(
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
                            onLocationSettingsPressed: () => _handleDestination(
                              context,
                              label: 'Location Settings',
                              override: onLocationSettingsPressed,
                            ),
                            onSosSettingsPressed: () => _handleDestination(
                              context,
                              label: 'SOS Settings',
                              override: onSosSettingsPressed,
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
    if (label == 'My Circles') {
      Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(builder: (_) => CircleSettingScreen.demo()),
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
    required this.onMyCirclesPressed,
    required this.onFriendsPressed,
    required this.onBlockedUsersPressed,
    required this.onPrivacySettingsPressed,
    required this.onLocationSettingsPressed,
    required this.onSosSettingsPressed,
  });

  final VoidCallback onMyCirclesPressed;
  final VoidCallback onFriendsPressed;
  final VoidCallback onBlockedUsersPressed;
  final VoidCallback onPrivacySettingsPressed;
  final VoidCallback onLocationSettingsPressed;
  final VoidCallback onSosSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: SettingsKeys.listCard,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            offset: Offset(0, 5),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SettingsListItem(
              key: SettingsKeys.item('circles'),
              icon: Icons.group_outlined,
              label: 'My Circles',
              onTap: onMyCirclesPressed,
            ),
            const SizedBox(height: 6),
            SettingsListItem(
              key: SettingsKeys.item('friends'),
              icon: Icons.people_outline,
              label: 'Friends',
              onTap: onFriendsPressed,
            ),
            const SizedBox(height: 6),
            SettingsListItem(
              key: SettingsKeys.item('blocked'),
              icon: Icons.person_off_outlined,
              label: 'Blocked Users',
              onTap: onBlockedUsersPressed,
            ),
            const SizedBox(height: 6),
            SettingsListItem(
              key: SettingsKeys.item('privacy'),
              icon: Icons.shield_outlined,
              label: 'Privacy Settings',
              onTap: onPrivacySettingsPressed,
            ),
            const SizedBox(height: 6),
            SettingsListItem(
              key: SettingsKeys.item('location'),
              icon: Icons.location_on_outlined,
              label: 'Location Settings',
              onTap: onLocationSettingsPressed,
            ),
            const SizedBox(height: 6),
            SettingsListItem(
              key: SettingsKeys.item('sos'),
              icon: Icons.error_outline_rounded,
              label: 'SOS Settings',
              onTap: onSosSettingsPressed,
            ),
            const SizedBox(height: 6),
            SettingsListItem(
              key: SettingsKeys.item('more_menu'),
              icon: Icons.more_horiz_rounded,
              label: 'More menu',
              onTap: () {
                Navigator.of(context).push<void>(
                  AppFadeSlidePageRoute<void>(
                    builder: (_) => const MoreMenuScreen(),
                  ),
                );
              },
            ),
          ],
        ),
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
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const SizedBox.expand(),
    );
  }
}
