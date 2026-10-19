import 'package:flutter/material.dart';

import '../../data/orbit_identity_client.dart';
import '../../../../app/routing/app_routes.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Account deletion request')),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _status,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: snapshot.hasError
                ? Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    const Text('Could not load deletion status.'),
                    TextButton(
                        onPressed: () => setState(() => _status = _identity.deletionStatus()),
                        child: const Text('Try again')),
                  ])
                : const CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final pending = data['status'] == 'pending';
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(pending ? 'Your account is scheduled for deletion.'
                    : 'There is no pending deletion request.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (pending) ...<Widget>[
                  const Text('Your account access is restricted. Your data has NOT yet been erased.'),
                  const SizedBox(height: 12),
                  Text('Earliest eligible erasure date: ${data['eligible_for_erasure_at'] ?? 'Unavailable'}'),
                  const SizedBox(height: 16),
                  if (data['can_cancel'] == true)
                    FilledButton(
                      onPressed: _busy ? null : _cancel,
                      child: Text(_busy ? 'Processing…' : 'Cancel deletion request'),
                    ),
                ],
                const SizedBox(height: 16),
                TextButton(onPressed: _busy ? null : _logout,
                    child: const Text('Sign out')),
              ],
            ),
          );
        },
      ),
    ),
  );
}
