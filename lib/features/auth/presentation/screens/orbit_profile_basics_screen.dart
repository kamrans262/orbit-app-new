import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/orbit_identity_client.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';

/// Saves the documented minimal account profile before consent onboarding.
class OrbitProfileBasicsScreen extends StatefulWidget {
  const OrbitProfileBasicsScreen({
    required this.onCompleted,
    this.initialName,
    super.key,
  });
  final VoidCallback onCompleted;
  final String? initialName;

  @override
  State<OrbitProfileBasicsScreen> createState() => _OrbitProfileBasicsScreenState();
}

class _OrbitProfileBasicsScreenState extends State<OrbitProfileBasicsScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    final username = _username.text.trim();
    if (name.length < 2 || !RegExp(r'^[a-zA-Z0-9._]{3,32}) {
      setState(() => _error = 'Enter a name and a username (3–32 letters, numbers, dots or underscores).');
      return;
    }
    if (_bio.text.trim().length > 280) {
      setState(() => _error = 'Bio must be 280 characters or fewer.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.completePendingPasswordEnrollment();
      await OrbitIdentityClient.instance.updateProfileBasics(name, username,
          bio: _bio.text.trim());
      OrbitIdentityClient.instance.finishStandardSignup();
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
            AppTextField(
              controller: _name,
              label: 'Full Name',
              hintText: 'Emma Johnson',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: _username,
              label: 'Username',
              hintText: 'Your username',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: _bio,
              label: 'Bio (optional)',
              hintText: 'A few words about you',
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLines: 3,
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
).hasMatch(username)) {
      setState(() => _error = 'Enter a name and a username (3–32 letters, numbers, _ or -).');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.completePendingPasswordEnrollment();
      await OrbitIdentityClient.instance.updateProfileBasics(name, username);
      OrbitIdentityClient.instance.finishStandardSignup();
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
            AppTextField(
              controller: _name,
              label: 'Full Name',
              hintText: 'Emma Johnson',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: _username,
              label: 'Username',
              hintText: 'Your username',
              textInputAction: TextInputAction.done,
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
