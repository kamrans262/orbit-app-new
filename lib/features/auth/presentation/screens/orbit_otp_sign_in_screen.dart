import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_otp_input.dart';
import '../widgets/orbit_auth_channel_selector.dart';
import '../../data/orbit_identity_client.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';

/// Backend-connected email/SMS OTP entry, separate from the older UI mockup.
class OrbitOtpSignInScreen extends StatefulWidget {
  const OrbitOtpSignInScreen({
    required this.onVerified,
    this.initialRecipient,
    this.initialChannel,
    this.initialPassword,
    this.sendImmediately = false,
    super.key,
  });
  final VoidCallback onVerified;
  final String? initialRecipient;
  final String? initialChannel;
  final String? initialPassword;
  final bool sendImmediately;

  @override
  State<OrbitOtpSignInScreen> createState() => _OrbitOtpSignInScreenState();
}

class _OrbitOtpSignInScreenState extends State<OrbitOtpSignInScreen> {
  final _recipient = TextEditingController();
  String _code = '';
  String? _password;
  String _channel = 'email';
  bool _requested = false;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipient?.trim() ?? '';
    _recipient.text = initial;
    _password = widget.initialPassword;
    _channel = widget.initialChannel ?? (initial.startsWith('+') ? 'sms' : 'email');
    if (widget.sendImmediately && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit();
      });
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() { _working = true; _error = null; });
    try {
      if (!_requested) {
        if (_password != null) {
          await OrbitIdentityClient.instance.requestPasswordCode(
              _recipient.text, _password!);
        } else {
          await OrbitIdentityClient.instance.requestCode(_channel, _recipient.text);
        }
        _password = null;
        if (mounted) setState(() => _requested = true);
      } else {
        await OrbitIdentityClient.instance.verifyCode(
          _channel, _recipient.text, _code,
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
              OrbitAuthChannelSelector(
                channel: _channel,
                enabled: !_working,
                onChanged: (next) => setState(() => _channel = next),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: _channel == 'email' ? 'Email' : 'Phone (with country code)',
                controller: _recipient,
                enabled: !_working,
                hintText: _channel == 'email'
                    ? 'example@email.com'
                    : '+923001234567',
                keyboardType: _channel == 'email'
                    ? TextInputType.emailAddress : TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
            ] else ...<Widget>[
              AppOtpInput(
                key: const Key('orbit_auth_otp_input'),
                enabled: !_working,
                autofocus: true,
                initialCode: _code,
                onChanged: (value) => setState(() => _code = value),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _working ? null : () => setState(() {
                  _requested = false;
                  _code = '';
                }),
                child: Text(
                  'Change destination',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryEnd,
                  ),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: AppTypography.body.copyWith(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: _working ? 'Please wait…' :
                  (_requested ? 'Verify Code' : 'Send Code'),
              enabled: !_working && (!_requested || _code.length == 6),
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
