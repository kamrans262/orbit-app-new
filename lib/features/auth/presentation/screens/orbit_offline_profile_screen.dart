import 'package:flutter/material.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';
import '../../data/orbit_identity_client.dart';

/// Deliberately NOT a replacement for authenticated Home. Displays only the
/// user's previously verified, fresh encrypted profile snapshot.
class OrbitOfflineProfileScreen extends StatefulWidget {
  const OrbitOfflineProfileScreen({super.key, this.identity});
  final OrbitIdentityClient? identity;

  @override
  State<OrbitOfflineProfileScreen> createState() =>
      _OrbitOfflineProfileScreenState();
}

class _OrbitOfflineProfileScreenState extends State<OrbitOfflineProfileScreen> {
  late final OrbitIdentityClient _identity =
      widget.identity ?? OrbitIdentityClient.instance;
  late Future<Map<String, dynamic>?> _cached =
      _identity.cachedProfileForOffline();
  bool _working = false;

  Future<void> _reconnect() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final state = await _identity.restoreSession();
      if (!mounted) return;
      final route = switch (state) {
        OrbitRestoreState.authenticated => AppRoutes.home,
        OrbitRestoreState.deletionPending => AppRoutes.deletionStatus,
        OrbitRestoreState.deviceRegistration => AppRoutes.deviceRegistration,
        OrbitRestoreState.signedOut => AppRoutes.login,
        OrbitRestoreState.offlineProfile => null,
      };
      if (route != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Still offline. Your profile remains read-only.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    if (_working) return;
    setState(() => _working = true);
    await _identity.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Widget _offlineActions({required bool cached}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AppPrimaryButton(
        label: _working ? 'Checking…' : cached ? 'Reconnect' : 'Try connecting again',
        enabled: !_working,
        onPressed: _reconnect,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _working ? null : _signOut,
        child: Text(cached ? 'Sign out and clear offline data' : 'Sign out',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: AppColors.primaryEnd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AuthScreenLayout(
    child: FutureBuilder<Map<String, dynamic>?>(
      future: _cached,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AuthCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryEnd),
            ),
          );
        }

        final profile = snapshot.data;
        return AuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppColors.primaryEnd,
              ),
              const SizedBox(height: 14),
              const AuthHeader(
                heading: 'Offline profile',
                subtitle: 'Your account cannot be verified without internet.',
              ),
              const SizedBox(height: 20),
              if (profile == null) ...<Widget>[
                Text(
                  'No valid offline profile is available.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                _offlineActions(cached: false),
              ] else ...<Widget>[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8EDFB),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'OFFLINE • READ ONLY',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primaryEnd,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  profile['display_name'] as String,
                  textAlign: TextAlign.center,
                  style: AppTypography.smallHeading,
                ),
                const SizedBox(height: 5),
                Text(
                  profile['username'] == null
                      ? 'Profile cached on this device'
                      : '@${profile['username']}',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if ((profile['bio'] as String? ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    profile['bio'] as String,
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'This is your last saved profile. We cannot verify '
                  'account or device changes while offline. Privacy changes, '
                  'messages, location and other account actions are unavailable.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 26),
                _offlineActions(cached: true),
              ],
            ],
          ),
        );
      },
    ),
  );
}
