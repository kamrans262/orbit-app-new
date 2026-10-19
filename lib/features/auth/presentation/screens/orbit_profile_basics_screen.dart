import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../data/orbit_identity_client.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';

/// Saves the documented minimal account profile before consent onboarding.
class OrbitProfileBasicsScreen extends StatefulWidget {
  const OrbitProfileBasicsScreen({required this.onCompleted, super.key});
  final VoidCallback onCompleted;

  @override
  State<OrbitProfileBasicsScreen> createState() => _OrbitProfileBasicsScreenState();
}

class _OrbitProfileBasicsScreenState extends State<OrbitProfileBasicsScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    final username = _username.text.trim();
    if (name.length < 2 || !RegExp(r'^[a-zA-Z0-9_-]{3,32}$').hasMatch(username)) {
      setState(() => _error = 'Enter a name and a username (3–32 letters, numbers, _ or -).');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.updateProfileBasics(name, username);
      if (mounted) widget.onCompleted();
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save your profile. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      child: AuthCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              heading: 'Your Orbit profile',
              subtitle: 'Set the name friends will recognize.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _username,
              maxLength: 32,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTypography.body.copyWith(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: _busy ? 'Saving…' : 'Continue',
              enabled: !_busy,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            Text('Your profile details can be updated later.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
