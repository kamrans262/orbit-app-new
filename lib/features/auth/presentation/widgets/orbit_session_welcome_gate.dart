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
          // Welcome remains accessible while the OS secure storage responds.
          // The protected Home route still performs an independent auth check.
          return widget.welcome;
        }
        final state = snapshot.data!;
        if (state != OrbitRestoreState.signedOut) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final route = state == OrbitRestoreState.authenticated
                ? '/home' : '/device-registration';
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
  const OrbitProtectedHome({required this.home, super.key});
  final Widget home;

  @override
  State<OrbitProtectedHome> createState() => _OrbitProtectedHomeState();
}

class _OrbitProtectedHomeState extends State<OrbitProtectedHome> {
  late final Future<OrbitRestoreState> _check =
      OrbitIdentityClient.instance.restoreSession();

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
              ? '/device-registration' : '/';
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
