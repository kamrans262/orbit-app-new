import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/orbit_identity_client.dart';

/// Prevents demo/mock navigation from being mistaken for a verified login.
class OrbitSessionWelcomeGate extends StatefulWidget {
  const OrbitSessionWelcomeGate({required this.welcome, super.key});
  final Widget welcome;

  @override
  State<OrbitSessionWelcomeGate> createState() => _OrbitSessionWelcomeGateState();
}

class _OrbitSessionWelcomeGateState extends State<OrbitSessionWelcomeGate> {
  late final Future<OrbitRestoreState> _check =
      OrbitIdentityClient.instance.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OrbitRestoreState>(
      future: _check,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // The production bootstrap resolves the route behind Splash.
          // Direct OrbitApp usages (including test/storybook navigation)
          // retain the existing Welcome behavior.
          return widget.welcome;
        }
        final state = snapshot.data!;
        if (state != OrbitRestoreState.signedOut) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final route = state == OrbitRestoreState.authenticated
                ? '/home'
                : state == OrbitRestoreState.deletionPending
                    ? '/deletion-status'
                    : state == OrbitRestoreState.offlineProfile
                        ? '/offline-profile' : '/device-registration';
            Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
          });
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.welcome;
      },
    );
  }
}

/// Auth gate at the home route as well as app startup. A non-authorized user
/// cannot reach demo Home through previous UI-only onboarding shortcuts.
class OrbitProtectedHome extends StatefulWidget {
  const OrbitProtectedHome({
    required this.home,
    this.identity,
    this.startupVerified = false,
    super.key,
  });
  final Widget home;
  final OrbitIdentityClient? identity;
  /// Only set from a session successfully verified before app startup.
  final bool startupVerified;

  @override
  State<OrbitProtectedHome> createState() => _OrbitProtectedHomeState();
}

class _OrbitProtectedHomeState extends State<OrbitProtectedHome> {
  late final Future<OrbitRestoreState> _check = widget.startupVerified
      ? Future<OrbitRestoreState>.value(OrbitRestoreState.authenticated)
      : (widget.identity ?? OrbitIdentityClient.instance).restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OrbitRestoreState>(
      future: _check,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == OrbitRestoreState.authenticated) {
          return widget.home;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final route = snapshot.data == OrbitRestoreState.deviceRegistration
              ? '/device-registration'
              : snapshot.data == OrbitRestoreState.deletionPending
                  ? '/deletion-status'
                  : snapshot.data == OrbitRestoreState.offlineProfile
                      ? '/offline-profile' : '/login';
          Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
        });
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
