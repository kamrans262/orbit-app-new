import 'package:flutter/material.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../data/orbit_identity_client.dart';

abstract final class OrbitSessionsKeys {
  static const title = Key('sessions_title');
  static const back = Key('sessions_back');
  static const retry = Key('sessions_retry');
  static const signOutAll = Key('sessions_sign_out_all');

  static Key row(String id) => ValueKey<String>('session_row_$id');
  static Key revoke(String id) => ValueKey<String>('session_revoke_$id');
}

/// Session management uses the same header, cards, buttons and popup system
/// as the other Orbit Profile/Settings screens. Never expose session tokens.
class OrbitSessionsScreen extends StatefulWidget {
  const OrbitSessionsScreen({this.onLoadSessions, super.key});

  /// Allows presentation tests with fixed data; production uses the live API.
  final Future<List<Map<String, dynamic>>> Function()? onLoadSessions;

  @override
  State<OrbitSessionsScreen> createState() => _OrbitSessionsScreenState();
}

class _OrbitSessionsScreenState extends State<OrbitSessionsScreen> {
  late Future<List<Map<String, dynamic>>> _sessions;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sessions = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      widget.onLoadSessions?.call() ?? OrbitIdentityClient.instance.sessions();

  void _reload() => setState(() => _sessions = _load());

  Future<bool> _confirm(String title, String message, String action) async {
    return await showOrbitPopupModal<bool>(
          context: context,
          builder: (dialogContext) => OrbitPopupModal(
            title: title,
            description: message,
            showCloseButton: true,
            onClose: () => Navigator.of(dialogContext).pop(false),
            primaryAction: OrbitPopupDestructiveButton(
              label: action,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
            secondaryAction: OrbitPopupTextButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ),
        ) ??
        false;
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _revoke(String id, bool current) async {
    if (_busy) return;
    final confirmed = await _confirm(
      current ? 'Sign out this device?' : 'Revoke this session?',
      'Revoked sessions can no longer access your Orbit account.',
      current ? 'Sign out' : 'Revoke',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await OrbitIdentityClient.instance.revokeSession(id);
      if (!mounted) return;
      if (current) {
        await OrbitIdentityClient.instance.clearSession();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
      } else {
        _reload();
      }
    } catch (_) {
      _error('Could not revoke this session. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAll() async {
    if (_busy) return;
    final confirmed = await _confirm(
      'Sign out on all devices?',
      'All active sessions will be revoked, including this device.',
      'Sign out all',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await OrbitIdentityClient.instance.signOutAll();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
    } catch (_) {
      _error('Could not revoke all sessions. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: AppScreenHeader(
                    title: 'Sessions',
                    titleKey: OrbitSessionsKeys.title,
                    backButtonKey: OrbitSessionsKeys.back,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _sessions,
                    builder: (context, snapshot) {
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: <Widget>[
                          Text('Devices signed into Orbit',
                              style: AppTypography.smallHeading),
                          const SizedBox(height: 6),
                          Text(
                            'Review signed-in devices, revoke a session or sign out everywhere.',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 18),
                          if (snapshot.connectionState != ConnectionState.done)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (snapshot.hasError) ...<Widget>[
                            const _InformationCard(
                              icon: Icons.error_outline_rounded,
                              heading: 'Could not load sessions',
                              detail: 'Check your connection and try again.',
                            ),
                            const SizedBox(height: 16),
                            AppPrimaryButton(
                              key: OrbitSessionsKeys.retry,
                              label: 'Try again',
                              onPressed: _reload,
                            ),
                          ] else if (snapshot.data!.isEmpty)
                            const _InformationCard(
                              icon: Icons.devices_other_rounded,
                              heading: 'No registered sessions',
                              detail: 'There are no sessions to display.',
                            )
                          else ...<Widget>[
                            for (final session in snapshot.data!) ...<Widget>[
                              _SessionCard(
                                key: OrbitSessionsKeys.row(session['id'] as String),
                                data: session,
                                busy: _busy,
                                onRevoke: () => _revoke(
                                  session['id'] as String,
                                  session['is_current'] == true,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),
                            AppPrimaryButton(
                              key: OrbitSessionsKeys.signOutAll,
                              label: _busy ? 'Processing…' : 'Sign out all devices',
                              enabled: !_busy,
                              onPressed: _signOutAll,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.data,
    required this.busy,
    required this.onRevoke,
    super.key,
  });

  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final rawName = (data['device_name'] as String?)?.trim();
    final name = rawName == null || rawName.isEmpty ? 'Unknown device' : rawName;
    final current = data['is_current'] == true;
    final revoked = data['revoked'] == true;
    final lastUsed = (data['last_used_at'] as String?)?.trim();
    final subtitle = <String>[
      current ? 'This device' : 'Another device',
      revoked ? 'Revoked' : 'Active',
      if (lastUsed != null && lastUsed.isNotEmpty) lastUsed,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x1FA576F6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.devices_other_rounded,
                  size: 24, color: AppColors.primaryEnd),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontSize: 12, color: AppColors.textMuted,
                    )),
                if (!revoked)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: OrbitSessionsKeys.revoke(data['id'] as String),
                      onPressed: busy ? null : onRevoke,
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: Text(current ? 'Sign out' : 'Revoke'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFAD3149)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.heading,
    required this.detail,
  });

  final IconData icon;
  final String heading;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 27, color: AppColors.primaryEnd),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(heading, style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(detail, style: AppTypography.body.copyWith(
              color: AppColors.textMuted, fontSize: 12)),
          ],
        )),
      ],
    ),
  );
}
