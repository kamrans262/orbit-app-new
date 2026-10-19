import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/orbit_identity_client.dart';
import '../../domain/orbit_auth_validation.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_screen_layout.dart';
import 'reset_password_screen.dart';
import 'verify_otp_screen.dart';

/// Reset requires a recovery-only OTP and a new password. It never signs in.
class OrbitPasswordResetFlow extends StatefulWidget {
  const OrbitPasswordResetFlow({required this.onCompleted, super.key});
  final VoidCallback onCompleted;

  @override
  State<OrbitPasswordResetFlow> createState() => _OrbitPasswordResetFlowState();
}

class _OrbitPasswordResetFlowState extends State<OrbitPasswordResetFlow> {
  final _password = TextEditingController();
  String? _recipient;
  String _code = '';
  int _step = 0;
  int _revision = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _send(String destination) async {
    if (_busy) return;
    final error = OrbitAuthValidation.recipient(destination);
    if (error != null) { setState(() => _error = error); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.requestPasswordResetCode(destination.trim());
      if (mounted) setState(() {
        _recipient = destination.trim();
        _step = 1;
        _revision++;
      });
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send a reset code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _recipient == null) return;
    final error = OrbitAuthValidation.password(_password.text);
    if (error != null) { setState(() => _error = error); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await OrbitIdentityClient.instance.confirmPasswordReset(
          _recipient!, _code, _password.text);
      // Reset revokes all previously issued mobile sessions, including this
      // device; never navigate into protected Home after a password reset.
      await OrbitIdentityClient.instance.clearSession();
      if (mounted) widget.onCompleted();
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reset password. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return Stack(
        children: <Widget>[
          ResetPasswordScreen(onSendResetLink: _send),
          if (_error != null) Positioned(
            left: 16, right: 16, bottom: 16,
            child: Text(_error!, textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: Colors.red))),
        ],
      );
    }
    if (_step == 1) {
      return VerifyOtpScreen(
        key: ValueKey('orbit_recovery_code_$_revision'),
        recipient: _recipient!,
        onVerifyCode: (value) => setState(() {
          _code = value;
          _step = 2;
          _error = null;
        }),
        initialCountdownSeconds: 60,
        onResendCode: () { _send(_recipient!); },
        onChangeDestination: () => setState(() { _step = 0; _error = null; }),
        errorMessage: _error,
      );
    }
    return AuthScreenLayout(
      child: AuthCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthHeader(
              heading: 'Set New Password',
              subtitle: 'Your code and new password will be verified together.',
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'New Password',
              controller: _password,
              obscureText: true,
              hintText: 'At least 10 characters',
              textInputAction: TextInputAction.done,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: AppTypography.body.copyWith(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: _busy ? 'Updating…' : 'Update Password',
              enabled: !_busy,
              onPressed: _confirm,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => setState(() {
                _step = 1;
                _error = null;
              }),
              child: Text('Change code', style: AppTypography.body.copyWith(
                color: AppColors.primaryEnd, fontWeight: FontWeight.w600,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
