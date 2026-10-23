import 'package:flutter/material.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';
import '../../data/orbit_identity_client.dart';

/// A restricted account may only review/cancel deletion, or sign out.
class OrbitAccountDeletionStatusScreen extends StatefulWidget {
  const OrbitAccountDeletionStatusScreen({super.key, this.identity});
  final OrbitIdentityClient? identity;

  @override
  State<OrbitAccountDeletionStatusScreen> createState() =>
      _OrbitAccountDeletionStatusScreenState();
}

class _OrbitAccountDeletionStatusScreenState
    extends State<OrbitAccountDeletionStatusScreen> {
  late final OrbitIdentityClient _identity =
      widget.identity ?? OrbitIdentityClient.instance;
  late Future<Map<String, dynamic>> _status = _identity.deletionStatus();
  bool _busy = false;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _identity.cancelDeletion();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on OrbitIdentityException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _identity.signOut();
    } catch (_) {
      await _identity.clearSession();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Widget _signOutAction() => TextButton(
    onPressed: _busy ? null : _logout,
    child: Text(
      'Sign out',
      style: AppTypography.body.copyWith(
        color: AppColors.primaryEnd,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AuthScreenLayout(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _status,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const AuthCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryEnd),
            ),
          );
        }

        if (snapshot.hasError) {
          return AuthCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.primaryEnd, size: 48),
                const SizedBox(height: 16),
                const AuthHeader(
                  heading: 'Account deletion request',
                  subtitle: 'Could not load deletion status.',
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Try again',
                  enabled: !_busy,
                  onPressed: () => setState(
                      () => _status = _identity.deletionStatus()),
                ),
                const SizedBox(height: 8),
                _signOutAction(),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final pending = data['status'] == 'pending';
        return AuthCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                pending ? Icons.shield_outlined : Icons.verified_user_outlined,
                color: AppColors.primaryEnd,
                size: 48,
              ),
              const SizedBox(height: 16),
              AuthHeader(
                heading: 'Account deletion request',
                subtitle: pending
                    ? 'Your account is scheduled for deletion.'
                    : 'There is no pending deletion request.',
              ),
              if (pending) ...<Widget>[
                const SizedBox(height: 22),
                Text(
                  'Your account access is restricted. '
                  'Your data has NOT yet been erased.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 12),
                Text(
                  'Earliest eligible erasure date: '
                  '${data['eligible_for_erasure_at'] ?? 'Unavailable'}',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (data['can_cancel'] == true) ...<Widget>[
                  const SizedBox(height: 26),
                  AppPrimaryButton(
                    label: _busy ? 'Processing…' : 'Cancel deletion request',
                    enabled: !_busy,
                    onPressed: _cancel,
                  ),
                ],
              ],
              const SizedBox(height: 12),
              _signOutAction(),
            ],
          ),
        );
      },
    ),
  );
}
