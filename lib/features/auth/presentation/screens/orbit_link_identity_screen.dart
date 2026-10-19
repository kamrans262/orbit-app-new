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

/// A verified email/phone can be added only to the current trusted account.
/// This never combines two existing independent Orbit accounts.
class OrbitLinkIdentityScreen extends StatefulWidget {
  const OrbitLinkIdentityScreen({super.key});

  @override
  State<OrbitLinkIdentityScreen> createState() => _OrbitLinkIdentityScreenState();
}

class _OrbitLinkIdentityScreenState extends State<OrbitLinkIdentityScreen> {
  final _recipient = TextEditingController();
  String _code = '';
  String _channel = 'email';
  bool _sent = false;
  bool _working = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() { _working = true; _error = null; });
    try {
      final identity = OrbitIdentityClient.instance;
      if (!_sent) {
        await identity.requestCode(_channel, _recipient.text, purpose: 'link');
        if (mounted) setState(() => _sent = true);
      } else {
        await identity.linkIdentity(_channel, _recipient.text, _code);
        if (mounted) setState(() => _done = true);
      }
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to verify this contact.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verified contacts', style: AppTypography.smallHeading),
        backgroundColor: AppColors.background,
      ),
      body: AuthScreenLayout(
        child: AuthCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              heading: _done ? 'Contact verified' : 'Add verified contact',
              subtitle: _done
                  ? 'This contact is now linked to your Orbit account.'
                  : 'Verify another email or phone number to access your same account.',
            ),
            const SizedBox(height: 20),
            if (!_sent && !_done) ...[
              OrbitAuthChannelSelector(
                channel: _channel,
                enabled: !_working,
                onChanged: (value) => setState(() => _channel = value),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: _channel == 'sms' ? 'Phone (with country code)' : 'Email',
                controller: _recipient,
                enabled: !_working,
                hintText: _channel == 'sms' ? '+923001234567' : 'example@email.com',
                keyboardType: _channel == 'sms'
                    ? TextInputType.phone : TextInputType.emailAddress,
              ),
            ],
            if (_sent && !_done) ...[
              Text('Verification code sent to ${_recipient.text.trim()}',
                  style: AppTypography.body),
              const SizedBox(height: 12),
              AppOtpInput(
                key: const Key('orbit_link_otp_input'),
                initialCode: _code,
                enabled: !_working,
                autofocus: true,
                onChanged: (value) => setState(() => _code = value),
              ),
              TextButton(
                onPressed: _working ? null : () => setState(() {
                  _sent = false;
                  _code = '';
                }),
                child: Text(
                  'Change contact',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryEnd,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTypography.body.copyWith(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: _done ? 'Done' : _working ? 'Please wait…'
                  : _sent ? 'Verify and link' : 'Send verification code',
              enabled: !_working,
              onPressed: _done ? () => Navigator.of(context).pop() : _submit,
            ),
          ],
        )),
      ),
    );
  }
}
