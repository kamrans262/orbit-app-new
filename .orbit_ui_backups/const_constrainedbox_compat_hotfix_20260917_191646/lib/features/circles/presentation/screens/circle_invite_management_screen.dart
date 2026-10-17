import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../profile/presentation/widgets/orbit_person_action_tile.dart';
import '../../domain/models/circle_invite.dart';
import '../widgets/circle_invite_segmented_control.dart';
import '../widgets/invite_status_badge.dart';
import 'circle_invite_detail_screen.dart';

abstract final class CircleInviteManagementKeys {
  static const backButton = Key('circle_invite_management_back_button');
  static const title = Key('circle_invite_management_title');
  static const segmentedControl = Key('circle_invite_management_segmented');
  static const loadingState = Key('circle_invite_management_loading');
  static const emptyState = Key('circle_invite_management_empty');
  static const errorState = Key('circle_invite_management_error');

  static Key tab(CircleInviteTab tab) => Key('circle_invite_tab_${tab.name}');
  static Key list(CircleInviteTab tab) => Key('circle_invite_list_${tab.name}');
  static Key tile(String id) => Key('circle_invite_tile_$id');
  static Key avatar(String id) => Key('circle_invite_avatar_$id');
  static Key status(String id) => Key('circle_invite_status_$id');
}

typedef CircleInviteTap = FutureOr<void> Function(CircleInvite invite);

class CircleInviteManagementScreen extends StatefulWidget {
  const CircleInviteManagementScreen({
    required this.sent,
    required this.pending,
    required this.accepted,
    this.initialTab = CircleInviteTab.sent,
    this.onBack,
    this.onInvitePressed,
    this.onRetry,
    super.key,
  });

  factory CircleInviteManagementScreen.demo({
    VoidCallback? onBack,
    CircleInviteTap? onInvitePressed,
  }) {
    return CircleInviteManagementScreen(
      sent: CircleInviteTabData(invites: CircleInvite.demoSent),
      pending: CircleInviteTabData(invites: CircleInvite.demoPending),
      accepted: CircleInviteTabData(invites: CircleInvite.demoAccepted),
      onBack: onBack,
      onInvitePressed: onInvitePressed,
    );
  }

  final CircleInviteTabData sent;
  final CircleInviteTabData pending;
  final CircleInviteTabData accepted;
  final CircleInviteTab initialTab;
  final VoidCallback? onBack;
  final CircleInviteTap? onInvitePressed;
  final ValueChanged<CircleInviteTab>? onRetry;

  @override
  State<CircleInviteManagementScreen> createState() =>
      _CircleInviteManagementScreenState();
}

class _CircleInviteManagementScreenState
    extends State<CircleInviteManagementScreen> {
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerGap = 20;
  static const double _segmentToListGap = 16;
  static const double _tileGap = 10;
  static const double _maxContentWidth = 600;

  late CircleInviteTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                _topPadding,
                _horizontalPadding,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: AppScreenHeader(
                    title: 'Circle Invite management',
                    onBack: widget.onBack,
                    backButtonKey: CircleInviteManagementKeys.backButton,
                    titleKey: CircleInviteManagementKeys.title,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _headerGap),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: KeyedSubtree(
                    key: CircleInviteManagementKeys.segmentedControl,
                    child: CircleInviteSegmentedControl(
                      value: _selectedTab,
                      onChanged: _selectTab,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _segmentToListGap),
            Expanded(
              child: IndexedStack(
                index: _selectedTab.index,
                children: CircleInviteTab.values
                    .map((tab) {
                      return KeyedSubtree(
                        key: CircleInviteManagementKeys.tab(tab),
                        child: _buildTab(tab),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(CircleInviteTab tab) {
    if (_selectedTab == tab) {
      return;
    }
    setState(() => _selectedTab = tab);
  }

  CircleInviteTabData _dataFor(CircleInviteTab tab) {
    switch (tab) {
      case CircleInviteTab.sent:
        return widget.sent;
      case CircleInviteTab.pending:
        return widget.pending;
      case CircleInviteTab.accepted:
        return widget.accepted;
    }
  }

  Widget _buildTab(CircleInviteTab tab) {
    final data = _dataFor(tab);
    switch (data.state) {
      case CircleInviteViewState.loading:
        return _buildLoadingList(tab);
      case CircleInviteViewState.error:
        return _buildMessageList(
          tab: tab,
          key: CircleInviteManagementKeys.errorState,
          icon: Icons.error_outline_rounded,
          title: 'Unable to load invites',
          message: data.errorMessage ?? 'Please try again.',
          actionLabel: widget.onRetry == null ? null : 'Try again',
          onAction: widget.onRetry == null ? null : () => widget.onRetry!(tab),
        );
      case CircleInviteViewState.empty:
        return _buildEmptyList(tab);
      case CircleInviteViewState.loaded:
        if (data.invites.isEmpty) {
          return _buildEmptyList(tab);
        }
        return _buildInviteList(tab, data.invites);
    }
  }

  Widget _buildInviteList(CircleInviteTab tab, List<CircleInvite> invites) {
    return ListView.separated(
      key: CircleInviteManagementKeys.list(tab),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        0,
        _horizontalPadding,
        _horizontalPadding,
      ),
      itemCount: invites.length,
      separatorBuilder: (context, index) => const SizedBox(height: _tileGap),
      itemBuilder: (context, index) {
        final invite = invites[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: OrbitPersonActionTile(
              containerKey: CircleInviteManagementKeys.tile(invite.id),
              avatarKey: CircleInviteManagementKeys.avatar(invite.id),
              name: invite.userName,
              avatarSource: invite.avatarUrl,
              semanticLabel: 'Open ${invite.userName} invite details',
              onTap: () => _openInvite(invite),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  KeyedSubtree(
                    key: CircleInviteManagementKeys.status(invite.id),
                    child: InviteStatusBadge(status: invite.status),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingList(CircleInviteTab tab) {
    return KeyedSubtree(
      key: CircleInviteManagementKeys.loadingState,
      child: ListView.separated(
        key: CircleInviteManagementKeys.list(tab),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          _horizontalPadding,
          0,
          _horizontalPadding,
          _horizontalPadding,
        ),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(height: _tileGap),
        itemBuilder: (context, index) {
          return const Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxContentWidth),
              child: _InviteLoadingTile(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyList(CircleInviteTab tab) {
    late final String label;
    switch (tab) {
      case CircleInviteTab.sent:
        label = 'No sent invites';
        break;
      case CircleInviteTab.pending:
        label = 'No pending invites';
        break;
      case CircleInviteTab.accepted:
        label = 'No accepted invites';
        break;
    }
    return _buildMessageList(
      tab: tab,
      key: CircleInviteManagementKeys.emptyState,
      icon: Icons.mail_outline_rounded,
      title: label,
      message: 'Invitations will appear here when they are available.',
    );
  }

  Widget _buildMessageList({
    required CircleInviteTab tab,
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ListView(
      key: CircleInviteManagementKeys.list(tab),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        0,
        _horizontalPadding,
        _horizontalPadding,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: _InviteMessageCard(
              key: key,
              icon: icon,
              title: title,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openInvite(CircleInvite invite) async {
    final callback = widget.onInvitePressed;
    if (callback != null) {
      await callback(invite);
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => CircleInviteDetailScreen(invite: invite),
      ),
    );
  }
}

class _InviteLoadingTile extends StatelessWidget {
  const _InviteLoadingTile();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: OrbitPersonActionTile.referenceHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OrbitPersonActionTile.radius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: <Widget>[
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFEDEFF3),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: OrbitPersonActionTile.avatarExtent,
                ),
              ),
              const SizedBox(width: OrbitPersonActionTile.avatarToNameGap),
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFEDEFF3),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: SizedBox(width: 92, height: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(width: 92, height: 35),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFFD1D5DB),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteMessageCard extends StatelessWidget {
  const _InviteMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 28, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F1724),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
