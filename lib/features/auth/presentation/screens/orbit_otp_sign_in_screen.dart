import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../data/orbit_identity_client.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';

/// Backend-connected email/SMS OTP entry, separate from the older UI mockup.
class OrbitOtpSignInScreen extends StatefulWidget {
  const OrbitOtpSignInScreen({required this.onVerified, super.key});
  final VoidCallback onVerified;

  @override
  State<OrbitOtpSignInScreen> createState() => _OrbitOtpSignInScreenState();
}

class _OrbitOtpSignInScreenState extends State<OrbitOtpSignInScreen> {
  final _recipient = TextEditingController();
  final _code = TextEditingController();
  String _channel = 'email';
  bool _requested = false;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() { _working = true; _error = null; });
    try {
      if (!_requested) {
        await OrbitIdentityClient.instance.requestCode(_channel, _recipient.text);
        if (mounted) setState(() => _requested = true);
      } else {
        await OrbitIdentityClient.instance.verifyCode(
          _channel, _recipient.text, _code.text,
        );
        if (mounted) widget.onVerified();
      }
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please retry.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      child: AuthCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AuthHeader(
              heading: _requested ? 'Enter the Code' : 'Verify your identity',
              subtitle: _requested
                  ? 'A six-digit code was sent to ${_recipient.text.trim()}'
                  : 'Use your verified email address or phone number.',
            ),
            const SizedBox(height: 22),
            if (!_requested) ...<Widget>[
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment(value: 'email', label: Text('Email')),
                  ButtonSegment(value: 'sms', label: Text('SMS')),
                ],
                selected: <String>{_channel},
                onSelectionChanged: (next) => setState(() => _channel = next.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _recipient,
                keyboardType: _channel == 'email'
                    ? TextInputType.emailAddress : TextInputType.phone,
                decoration: InputDecoration(
                  labelText: _channel == 'email' ? 'Email' : 'Phone (with country code)',
                  hintText: _channel == 'email'
                      ? 'you@example.com' : '+923001234567',
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else ...<Widget>[
              TextField(
                controller: _code,
                autofocus: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              TextButton(
                onPressed: _working ? null : () => setState(() {
                  _requested = false;
                  _code.clear();
                }),
                child: const Text('Change destination'),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: AppTypography.body.copyWith(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: _working ? 'Please wait…' :
                  (_requested ? 'Verify code' : 'Send code'),
              enabled: !_working,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Text('Codes expire in five minutes. SMS delivery may be limited during the trial.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
