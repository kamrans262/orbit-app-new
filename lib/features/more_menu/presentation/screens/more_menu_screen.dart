import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../widgets/more_menu_tile.dart';
import 'more_menu_destination_screen.dart';
import '../../../help_center/presentation/screens/help_center_screen.dart'
    as help_center;
import '../../../app_update/presentation/orbit_update_runtime.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../../../core/services/orbit_share_service.dart';

abstract final class MoreMenuKeys {
  static const scrollView = Key('more_menu_scroll_view');
  static const backButton = Key('more_menu_back_button');
  static const title = Key('more_menu_title');
  static const deleteConfirmButton = Key('more_menu_delete_confirm');
  static const logoutConfirmButton = Key('more_menu_logout_confirm');

  static Key tile(String id) => Key('more_menu_tile_$id');
  static Key icon(String id) => Key('more_menu_icon_$id');
  static Key label(String id) => Key('more_menu_label_$id');
  static Key chevron(String id) => Key('more_menu_chevron_$id');
}

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({
    this.labels = const MoreMenuLabels(),
    this.onBack,
    this.onWhatsNewPressed,
    this.onRateOrbitPressed,
    this.onShareOrbitPressed,
    this.onHelpCenterPressed,
    this.onTermsPressed,
    this.onPrivacyPressed,
    this.onDeleteAccountConfirmed,
    this.onLogoutConfirmed,
    super.key,
  });

  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerToListGap = 20;
  static const double _tileGap = 10;
  static const double _maxContentWidth = 430;

  final MoreMenuLabels labels;
  final VoidCallback? onBack;
  final VoidCallback? onWhatsNewPressed;
  final VoidCallback? onRateOrbitPressed;
  final VoidCallback? onShareOrbitPressed;
  final VoidCallback? onHelpCenterPressed;
  final VoidCallback? onTermsPressed;
  final VoidCallback? onPrivacyPressed;
  final VoidCallback? onDeleteAccountConfirmed;
  final VoidCallback? onLogoutConfirmed;

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          key: MoreMenuKeys.scrollView,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                _topPadding,
                _horizontalPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: AppScreenHeader(
                      title: 'Orbit Menu',
                      backButtonKey: MoreMenuKeys.backButton,
                      titleKey: MoreMenuKeys.title,
                      onBack: onBack,
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _headerToListGap)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: _tileGap);
                  }

                  final item = items[index ~/ 2];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth,
                      ),
                      child: MoreMenuTile(
                        containerKey: MoreMenuKeys.tile(item.id),
                        iconCircleKey: MoreMenuKeys.icon(item.id),
                        titleKey: MoreMenuKeys.label(item.id),
                        chevronKey: MoreMenuKeys.chevron(item.id),
                        icon: item.icon,
                        iconColor: item.iconColor,
                        iconBackgroundColor: item.iconBackgroundColor,
                        title: item.title,
                        titleColor: item.titleColor,
                        onTap: item.onTap,
                      ),
                    ),
                  );
                }, childCount: items.isEmpty ? 0 : (items.length * 2) - 1),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  List<_MoreMenuItemData> _buildItems(BuildContext context) {
    return <_MoreMenuItemData>[
      _MoreMenuItemData(
        id: 'whats_new',
        title: labels.whatsNew,
        icon: Icons.star_border_rounded,
        iconColor: const Color(0xFF7C3AED),
        iconBackgroundColor: const Color(0xFFF2EAFE),
        onTap: () => _handleWhatsNew(context),
      ),
      _MoreMenuItemData(
        id: 'rate_orbit',
        title: labels.rateOrbit,
        icon: Icons.star_border_rounded,
        iconColor: const Color(0xFFF43F8E),
        iconBackgroundColor: const Color(0xFFFFDCEB),
        onTap: () => _handleRateOrbit(context),
      ),
      _MoreMenuItemData(
        id: 'share_orbit',
        title: labels.shareOrbit,
        icon: Icons.share_outlined,
        iconColor: const Color(0xFF1DBE8A),
        iconBackgroundColor: const Color(0xFFDFF6EF),
        onTap: () => _handleShareOrbit(context),
      ),
      _MoreMenuItemData(
        id: 'help_center',
        title: labels.helpCenter,
        icon: Icons.phone_in_talk_outlined,
        iconColor: const Color(0xFFF44336),
        iconBackgroundColor: const Color(0xFFFADAD8),
        onTap: () => _handleHelpCenter(context),
      ),
      _MoreMenuItemData(
        id: 'terms',
        title: labels.termsOfServices,
        icon: Icons.description_outlined,
        iconColor: const Color(0xFF47C7D4),
        iconBackgroundColor: const Color(0xFFDDF7F3),
        onTap: () => _handleTerms(context),
      ),
      _MoreMenuItemData(
        id: 'privacy',
        title: labels.privacyPolicy,
        icon: Icons.description_outlined,
        iconColor: const Color(0xFFF59E0B),
        iconBackgroundColor: const Color(0xFFFFF0C7),
        onTap: () => _handlePrivacy(context),
      ),
      _MoreMenuItemData(
        id: 'delete_account',
        title: labels.deleteAccount,
        icon: Icons.delete_outline_rounded,
        iconColor: const Color(0xFFF44336),
        iconBackgroundColor: const Color(0xFFFADDDD),
        onTap: () => _confirmDeleteAccount(context),
      ),
      _MoreMenuItemData(
        id: 'logout',
        title: labels.logOut,
        icon: Icons.logout_rounded,
        iconColor: const Color(0xFFF44336),
        iconBackgroundColor: const Color(0xFFFADADA),
        titleColor: const Color(0xFFF44336),
        onTap: () => _confirmLogout(context),
      ),
    ];
  }

  void _handleWhatsNew(BuildContext context) {
    if (onWhatsNewPressed != null) {
      onWhatsNewPressed!();
      return;
    }
    showLatestOrbitUpdatePopup(context);
  }

  void _handleHelpCenter(BuildContext context) {
    if (onHelpCenterPressed != null) {
      onHelpCenterPressed!();
      return;
    }
    _push(context, const help_center.HelpCenterScreen());
  }

  void _handleTerms(BuildContext context) {
    if (onTermsPressed != null) {
      onTermsPressed!();
      return;
    }
    _push(context, const TermsOfServicesScreen());
  }

  void _handlePrivacy(BuildContext context) {
    if (onPrivacyPressed != null) {
      onPrivacyPressed!();
      return;
    }
    _push(context, const PrivacyPolicyScreen());
  }

  void _handleRateOrbit(BuildContext context) {
    if (onRateOrbitPressed != null) {
      onRateOrbitPressed!();
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Rate Orbit',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F1724),
            ),
          ),
          content: const Text(
            'Choose a rating. The native App Store / Play Store review action can replace this callback later.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            Wrap(
              alignment: WrapAlignment.center,
              children: List<Widget>.generate(5, (index) {
                return IconButton(
                  tooltip: '${index + 1} star',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Thanks for rating Orbit ${index + 1}/5.',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF43F8E),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleShareOrbit(BuildContext context) async {
    if (onShareOrbitPressed != null) {
      onShareOrbitPressed!();
      return;
    }

    await OrbitShareService.shareOrbit();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    await showDeleteAccountPopup(
      context,
      onDelete: () {
        if (!context.mounted) return;
        if (onDeleteAccountConfirmed != null) {
          onDeleteAccountConfirmed!();
          return;
        }
        _showUiOnlyMessage(
          context,
          'Delete account confirmed. Connect the backend delete action here.',
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    await showLogoutPopup(
      context,
      onLogout: () {
        if (!context.mounted) return;
        if (onLogoutConfirmed != null) {
          onLogoutConfirmed!();
          return;
        }
        _showUiOnlyMessage(
          context,
          'Logout confirmed. Connect the existing auth-session logout action here.',
        );
      },
      onCancel: () {},
    );
  }

  void _push(BuildContext context, Widget destination) {
    Navigator.of(context)
        .push<void>(AppFadeSlidePageRoute<void>(builder: (_) => destination));
  }

  void _showUiOnlyMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: AppTypography.fontFamily),
        ),
      ),
    );
  }
}

class MoreMenuLabels {
  const MoreMenuLabels({
    this.whatsNew = "What's New",
    this.rateOrbit = 'Rate Orbit',
    this.shareOrbit = 'Share Orbit',
    this.helpCenter = 'Help Center',
    this.termsOfServices = 'Terms of services',
    this.privacyPolicy = 'Privacy policy',
    this.deleteAccount = 'Delete Account',
    this.logOut = 'Log Out',
  });

  final String whatsNew;
  final String rateOrbit;
  final String shareOrbit;
  final String helpCenter;
  final String termsOfServices;
  final String privacyPolicy;
  final String deleteAccount;
  final String logOut;
}

class _MoreMenuItemData {
  const _MoreMenuItemData({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onTap,
    this.titleColor = const Color(0xFF0F1724),
  });

  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color titleColor;
  final VoidCallback onTap;
}
