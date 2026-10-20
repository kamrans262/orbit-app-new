import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/routing/app_routes.dart';
import '../../data/orbit_identity_client.dart';

/// Live session controls. Never display or log bearer/refresh tokens.
class OrbitSessionsScreen extends StatefulWidget {
  const OrbitSessionsScreen({super.key});

  @override
  State<OrbitSessionsScreen> createState() => _OrbitSessionsScreenState();
}

class _OrbitSessionsScreenState extends State<OrbitSessionsScreen> {
  late Future<List<Map<String, dynamic>>> _sessions = OrbitIdentityClient.instance.sessions();
  bool _busy = false;
  String? _error;

  void _reload() {
    setState(() {
      _error = null;
      _sessions = OrbitIdentityClient.instance.sessions();
    });
  }

  Future<void> _revoke(String id, bool current) async {
    if (_busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current ? 'Sign out this device?' : 'Revoke this session?'),
        content: const Text('Revoked sessions can no longer access your Orbit account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Revoke')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.revokeSession(id);
      if (current) {
        await OrbitIdentityClient.instance.clearSession();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        return;
      }
      _reload();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not revoke this session.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAll() async {
    if (_busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out on all devices?'),
        content: const Text('All active sessions will be revoked, including this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out all')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.signOutAll();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not revoke all sessions. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sessions', style: AppTypography.smallHeading),
        backgroundColor: AppColors.background, foregroundColor: AppColors.textPrimary),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sessions,
        builder: (context, snapshot) {
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('Devices signed into Orbit', style: AppTypography.smallHeading),
            const SizedBox(height: 8),
            Text('You can revoke an individual session or sign out everywhere.',
                style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              OutlinedButton(onPressed: _reload, child: const Text('Could not load sessions. Retry'))
            else if (snapshot.data!.isEmpty)
              const Text('No sessions found.')
            else
              for (final session in snapshot.data!)
                Card(color: Colors.white, child: ListTile(
                  title: Text((session['device_name'] as String?) ?? 'Unknown device'),
                  subtitle: Text([
                    session['is_current'] == true ? 'This device' : 'Another device',
                    session['revoked'] == true ? 'Revoked' : 'Active',
                    (session['last_used_at'] as String?) ?? 'No recent activity',
                  ].join(' · ')),
                  trailing: session['revoked'] == true
                      ? null
                      : TextButton(
                          onPressed: _busy ? null : () => _revoke(
                            session['id'] as String, session['is_current'] == true),
                          child: const Text('Revoke')),
                )),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signOutAll,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out all devices'),
            ),
          ]);
        },
      ),
    );
  }
}
