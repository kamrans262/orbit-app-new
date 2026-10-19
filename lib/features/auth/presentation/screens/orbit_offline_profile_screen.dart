import 'package:flutter/material.dart';

import '../../../../app/routing/app_routes.dart';
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
        OrbitRestoreState.signedOut => AppRoutes.welcome,
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
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Offline profile')),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _cached,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('No valid offline profile is available.'),
                TextButton(onPressed: _working ? null : _reconnect,
                    child: const Text('Try connecting again')),
                TextButton(onPressed: _working ? null : _signOut,
                    child: const Text('Sign out')),
              ],
            ));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('OFFLINE • READ ONLY',
                    style: TextStyle(color: Color(0xFF7C3AED),
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Text(profile['display_name'] as String,
                    style: const TextStyle(fontSize: 26,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                Text(profile['username'] == null
                    ? 'Profile cached on this device'
                    : '@${profile['username']}'),
                const SizedBox(height: 16),
                if ((profile['bio'] as String? ?? '').isNotEmpty)
                  Text(profile['bio'] as String),
                const SizedBox(height: 24),
                const Text('This is your last saved profile. We cannot verify '
                    'account or device changes while offline. Privacy changes, '
                    'messages, location and other account actions are unavailable.'),
                const Spacer(),
                SizedBox(width: double.infinity,
                  child: FilledButton(
                    onPressed: _working ? null : _reconnect,
                    child: Text(_working ? 'Checking…' : 'Reconnect'),
                  )),
                SizedBox(width: double.infinity,
                  child: TextButton(
                    onPressed: _working ? null : _signOut,
                    child: const Text('Sign out and clear offline data'),
                  )),
              ],
            ),
          );
        },
      ),
    ),
  );
}
