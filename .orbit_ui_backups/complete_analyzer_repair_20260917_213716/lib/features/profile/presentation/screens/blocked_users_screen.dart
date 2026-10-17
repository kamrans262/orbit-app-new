import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../domain/models/user_privacy_entry.dart';

abstract final class BlockUsersKeys {
  static const scrollView = Key('block_users_scroll_view');
  static const backButton = Key('block_users_back_button');
  static const title = Key('block_users_title');
  static const loadingState = Key('block_users_loading_state');
  static const emptyState = Key('block_users_empty_state');
  static const errorState = Key('block_users_error_state');

  static Key tile(String id) => Key('block_users_tile_$id');
  static Key avatar(String id) => Key('block_users_avatar_$id');
  static Key action(String id) => Key('block_users_action_$id');
}

typedef BlockUserRequest = FutureOr<void> Function(UserPrivacyEntry user);

class BlockUsersScreen extends StatefulWidget {
  const BlockUsersScreen({
    this.users,
    this.blockedUsers,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onBlockRequested,
    this.onBack,
    super.key,
  });

  /// API-ready entries. When omitted the Figma demo data is shown.
  final List<UserPrivacyEntry>? users;

  /// Compatibility input retained for the placeholder screen installed by the
  /// earlier Privacy Settings package. New code should use [users].
  final List<String>? blockedUsers;

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final BlockUserRequest? onBlockRequested;
  final VoidCallback? onBack;

  @override
  State<BlockUsersScreen> createState() => _BlockUsersScreenState();
}

class _BlockUsersScreenState extends State<BlockUsersScreen> {
  static const double _screenPadding = 20;
  static const double _headerGap = 20;
  static const double _tileGap = 10;
  static const double _maxContentWidth = 600;

  late List<UserPrivacyEntry> _users;

  @override
  void initState() {
    super.initState();
    _users = _resolveUsers();
  }

  @override
  void didUpdateWidget(covariant BlockUsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.users, widget.users) ||
        !identical(oldWidget.blockedUsers, widget.blockedUsers)) {
      _users = _resolveUsers();
    }
  }

  List<UserPrivacyEntry> _resolveUsers() {
    final apiUsers = widget.users;
    if (apiUsers != null) {
      return List<UserPrivacyEntry>.of(apiUsers);
    }

    final legacyUsers = widget.blockedUsers;
    if (legacyUsers != null) {
      return List<UserPrivacyEntry>.generate(
        legacyUsers.length,
        (index) => UserPrivacyEntry(
          id: 'legacy_$index',
          name: legacyUsers[index],
          avatarUrl: '',
          isBlocked: true,
        ),
      );
    }

    return List<UserPrivacyEntry>.of(UserPrivacyEntry.demoUsers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _screenPadding,
                _screenPadding,
                _screenPadding,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: AppScreenHeader(
                    title: 'Block Users',
                    onBack: widget.onBack,
                    backButtonKey: BlockUsersKeys.backButton,
                    titleKey: BlockUsersKeys.title,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _headerGap),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = widget.errorMessage;
    if (widget.isLoading) {
      return KeyedSubtree(
        key: BlockUsersKeys.loadingState,
        child: ListView.separated(
          key: BlockUsersKeys.scrollView,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            _screenPadding,
            0,
            _screenPadding,
            _screenPadding,
          ),
          itemCount: 3,
          separatorBuilder: (context, index) =>
              const SizedBox(height: _tileGap),
          itemBuilder: (context, index) => const _BlockUserLoadingTile(),
        ),
      );
    }

    if (error != null && error.trim().isNotEmpty) {
      return ListView(
        key: BlockUsersKeys.scrollView,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          _screenPadding,
          0,
          _screenPadding,
          _screenPadding,
        ),
        children: <Widget>[
          _BlockUsersMessageCard(
            key: BlockUsersKeys.errorState,
            icon: Icons.error_outline_rounded,
            title: 'Unable to load users',
            message: error,
            actionLabel: widget.onRetry == null ? null : 'Try again',
            onAction: widget.onRetry,
          ),
        ],
      );
    }

    if (_users.isEmpty) {
      return ListView(
        key: BlockUsersKeys.scrollView,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          _screenPadding,
          0,
          _screenPadding,
          _screenPadding,
        ),
        children: const <Widget>[
          _BlockUsersMessageCard(
            key: BlockUsersKeys.emptyState,
            icon: Icons.person_off_outlined,
            title: 'No users to show',
            message: 'People available to block will appear here.',
          ),
        ],
      );
    }

    return ListView.separated(
      key: BlockUsersKeys.scrollView,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        _screenPadding,
        0,
        _screenPadding,
        _screenPadding,
      ),
      itemCount: _users.length,
      separatorBuilder: (context, index) => const SizedBox(height: _tileGap),
      itemBuilder: (context, index) {
        final user = _users[index];
        return BlockUserTile(
          key: BlockUsersKeys.tile(user.id),
          user: user,
          onPressed: () => _handleUserAction(index),
        );
      },
    );
  }

  Future<void> _handleUserAction(int index) async {
    final user = _users[index];
    if (user.isBlocked) {
      setState(() {
        _users[index] = user.copyWith(isBlocked: false);
      });
      return;
    }

    final shouldBlock = await _showBlockConfirmation(user);
    if (!mounted || !shouldBlock) {
      return;
    }

    final callback = widget.onBlockRequested;
    if (callback != null) {
      await callback(user);
      if (!mounted) {
        return;
      }
    }

    setState(() {
      _users[index] = user.copyWith(isBlocked: true);
    });
  }

  Future<bool> _showBlockConfirmation(UserPrivacyEntry user) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Block ${user.name}?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1724),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'They will no longer be able to interact with you in the applicable areas.',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _DialogAction(
                      label: 'Cancel',
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                    const SizedBox(width: 8),
                    _DialogAction(
                      label: 'Block',
                      destructive: true,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }
}

class BlockUserTile extends StatelessWidget {
  const BlockUserTile({required this.user, required this.onPressed, super.key});

  static const double referenceHeight = 67;
  static const double radius = 30;
  static const double avatarExtent = 50;
  static const double avatarToNameGap = 6;
  static const double buttonWidth = 73;
  static const double buttonHeight = 35;

  final UserPrivacyEntry user;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: referenceHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: <Widget>[
              _BlockUserAvatar(
                key: BlockUsersKeys.avatar(user.id),
                source: user.avatarUrl,
                name: user.name,
              ),
              const SizedBox(width: avatarToNameGap),
              Expanded(
                child: Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: user.isBlocked
                    ? 'Unblock ${user.name}'
                    : 'Block ${user.name}',
                child: GestureDetector(
                  key: BlockUsersKeys.action(user.id),
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: Container(
                    width: buttonWidth,
                    height: buttonHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: user.isBlocked
                          ? const Color(0x1A7C3AED)
                          : const Color(0x26DC3232),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.isBlocked ? 'Unblock' : 'Block',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: user.isBlocked
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFF44336),
                      ),
                    ),
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

class _BlockUserAvatar extends StatelessWidget {
  const _BlockUserAvatar({required this.source, required this.name, super.key});

  final String source;
  final String name;

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(name: name);
    Widget image;

    if (source.startsWith('http://') || source.startsWith('https://')) {
      image = Image.network(
        source,
        width: BlockUserTile.avatarExtent,
        height: BlockUserTile.avatarExtent,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      );
    } else if (source.trim().isNotEmpty) {
      image = Image.asset(
        source,
        width: BlockUserTile.avatarExtent,
        height: BlockUserTile.avatarExtent,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else {
      image = fallback;
    }

    return Container(
      width: BlockUserTile.avatarExtent,
      height: BlockUserTile.avatarExtent,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(child: image),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: BlockUserTile.avatarExtent,
      height: BlockUserTile.avatarExtent,
      color: const Color(0xFFF2EAFE),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _BlockUserLoadingTile extends StatelessWidget {
  const _BlockUserLoadingTile();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: BlockUserTile.referenceHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BlockUserTile.radius),
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
                child: SizedBox.square(dimension: BlockUserTile.avatarExtent),
              ),
              const SizedBox(width: BlockUserTile.avatarToNameGap),
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFEDEFF3),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: SizedBox(width: 100, height: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E3E3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(
                  width: BlockUserTile.buttonWidth,
                  height: BlockUserTile.buttonHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockUsersMessageCard extends StatelessWidget {
  const _BlockUsersMessageCard({
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
            _DialogAction(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0x26DC3232)
              : const Color(0xFFF4F1F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: destructive
                ? const Color(0xFFF44336)
                : const Color(0xFF0F1724),
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible class retained because Profile Settings from the
/// previous package already imports/constructs `BlockedUsersScreen`.
class BlockedUsersScreen extends BlockUsersScreen {
  const BlockedUsersScreen({
    List<UserPrivacyEntry>? users,
    List<String>? blockedUsers,
    bool isLoading = false,
    String? errorMessage,
    VoidCallback? onRetry,
    BlockUserRequest? onBlockRequested,
    VoidCallback? onBack,
    Key? key,
  }) : super(
         users: users,
         blockedUsers: blockedUsers,
         isLoading: isLoading,
         errorMessage: errorMessage,
         onRetry: onRetry,
         onBlockRequested: onBlockRequested,
         onBack: onBack,
         key: key,
       );
}
