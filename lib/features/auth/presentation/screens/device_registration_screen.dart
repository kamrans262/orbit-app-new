import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/auth_card.dart';
import '../../data/orbit_identity_client.dart';

abstract final class DeviceRegistrationKeys {
  static const heading = Key('device_registration_heading');
  static const back = Key('device_registration_back');
  static const deviceCard = Key('device_registration_device_card');
  static const action = Key('device_registration_action');
  static const error = Key('device_registration_error');
  static const recoveryLink = Key('device_recovery_link');
  static const recoveryRecipient = Key('device_recovery_recipient');
  static const recoveryPassword = Key('device_recovery_password');
  static const recoveryCode = Key('device_recovery_code');
  static const recoveryAction = Key('device_recovery_action');
}

/// The Device Registration presentation surface.
///
/// [onRegisterDevice] is the future backend integration point: it must generate
/// an identity keypair locally, keep the private key on-device, and return true
/// only after the server has acknowledged the public-key registration.
/// This UI deliberately does NOT create mock keys or claim device registration
/// succeeds while that backend / secure-storage integration is unavailable.
class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({
    required this.onBack,
    required this.onContinue,
    this.onRegisterDevice,
    this.onCheckApproval,
    this.onRequestRecoveryCode,
    this.onCompleteRecovery,
    this.deviceName = 'This device',
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final Future<bool> Function()? onRegisterDevice;
  final Future<bool> Function()? onCheckApproval;
  final Future<void> Function(String recipient, String password)? onRequestRecoveryCode;
  final Future<void> Function(String recipient, String password, String code)? onCompleteRecovery;
  final String deviceName;

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  bool _registering = false;
  bool _waitingForApproval = false;
  String? _error;
  bool _recoveryMode = false;
  bool _recoveryCodeSent = false;
  final _recipient = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _recipient.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    if (_registering || widget.onRequestRecoveryCode == null ||
        widget.onCompleteRecovery == null) return;
    final recipient = _recipient.text.trim();
    final password = _password.text;
    final code = _code.text.trim();
    if (recipient.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your registered email/phone and account password.');
      return;
    }
    if (_recoveryCodeSent && !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit recovery code.');
      return;
    }
    setState(() { _registering = true; _error = null; });
    try {
      if (!_recoveryCodeSent) {
        await widget.onRequestRecoveryCode!(recipient, password);
        if (!mounted) return;
        setState(() => _recoveryCodeSent = true);
      } else {
        await widget.onCompleteRecovery!(recipient, password, code);
        if (!mounted) return;
        _password.clear();
        _code.clear();
        widget.onContinue();
      }
    } on OrbitIdentityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error =
          'Unable to verify recovery right now. Please try again.');
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }
  Future<void> _handleAction() async {
    if (_registering) return;

    // UI-only build: proceed with the existing visual onboarding path without
    // falsely storing a 'registered device' flag or representing keys as saved.
    final register = widget.onRegisterDevice;
    if (register == null) {
      widget.onContinue();
      return;
    }

    setState(() {
      _registering = true;
      _error = null;
    });

    try {
      if (_waitingForApproval && widget.onCheckApproval != null) {
        final approved = await widget.onCheckApproval!();
        if (!mounted) return;
        if (approved) {
          widget.onContinue();
        } else {
          setState(() => _error =
              'Waiting for approval. Open Settings → Devices on your trusted phone and approve this device.');
        }
      } else {
        final registered = await register();
        if (!mounted) return;
        if (registered) {
          widget.onContinue();
        } else {
          setState(() => _error = 'Device registration was not completed. Try again.');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is OrbitIdentityException && error.statusCode == 403) {
            _waitingForApproval = true;
            _error = 'Waiting for approval. Open Settings → Devices on your trusted phone and approve this device.';
          } else {
            _error = error.toString().replaceFirst('OrbitIdentityException: ', '');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.onRegisterDevice == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, compact ? 12 : 30, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppCircularIconButton(
                          key: DeviceRegistrationKeys.back,
                          semanticLabel: 'Back',
                          onPressed: _registering ? () {} : widget.onBack,
                          icon: Icons.chevron_left_rounded,
                          iconSize: 24,
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 28),
                      const Text(
                        'Register Your Device',
                        key: DeviceRegistrationKeys.heading,
                        textAlign: TextAlign.center,
                        style: AppTypography.largeHeading,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Secure your private conversations and keep your circle close.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 42),
                      AuthCard(
                        cardKey: DeviceRegistrationKeys.deviceCard,
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              Icons.phonelink_lock_rounded,
                              size: 64,
                              color: AppColors.primaryEnd,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              widget.deviceName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.smallHeading,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your encryption keys will be created on this device. Only the public key will be sent to Orbit.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (preview) ...<Widget>[
                              const SizedBox(height: 16),
                              Text(
                                'Device registration will be enabled when your account backend is connected.',
                                textAlign: TextAlign.center,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.primaryEnd,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          key: DeviceRegistrationKeys.error,
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: const Color(0xFFC43346),
                          ),
                        ),
                      ],
                      if (_recoveryMode) ...<Widget>[
                        const SizedBox(height: 24),
                        AuthCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text('Recover device access',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.smallHeading),
                              const SizedBox(height: 12),
                              Text(
                                'If you no longer have access to any trusted device, '
                                'verify your password and a fresh code sent to your '
                                'registered email or phone.',
                                style: AppTypography.body.copyWith(
                                    color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              AppTextField(
                                label: 'Registered email or phone',
                                fieldKey: DeviceRegistrationKeys.recoveryRecipient,
                                controller: _recipient,
                                enabled: !_recoveryCodeSent && !_registering,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                label: 'Account password',
                                fieldKey: DeviceRegistrationKeys.recoveryPassword,
                                controller: _password,
                                enabled: !_registering,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                              ),
                              if (_recoveryCodeSent) ...<Widget>[
                                const SizedBox(height: 14),
                                AppTextField(
                                  label: 'Six-digit recovery code',
                                  fieldKey: DeviceRegistrationKeys.recoveryCode,
                                  controller: _code,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Recovering access will permanently sign out '
                                  'all previous trusted installations. Some '
                                  'end-to-end encrypted content may be unreadable '
                                  'if its old private keys were lost.',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                key: DeviceRegistrationKeys.recoveryAction,
                                child: AppPrimaryButton(
                                  label: _registering ? 'Verifying…'
                                      : _recoveryCodeSent
                                          ? 'Recover and sign out old devices'
                                          : 'Send recovery code',
                                  enabled: !_registering,
                                  onPressed: _recover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _registering ? null : () => setState(() {
                                  _recoveryMode = false;
                                  _recoveryCodeSent = false;
                                  _error = null;
                                  _password.clear();
                                  _code.clear();
                                }),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...<Widget>[
                        SizedBox(height: compact ? 26 : 42),
                        SizedBox(
                          key: DeviceRegistrationKeys.action,
                          child: AppPrimaryButton(
                            label: _registering
                                ? 'Checking…'
                                : preview
                                ? 'Continue'
                                : _waitingForApproval
                                ? 'Check Approval'
                                : 'Register Device',
                            enabled: !_registering,
                            onPressed: _handleAction,
                          ),
                        ),
                        if (_waitingForApproval && !preview &&
                            widget.onRequestRecoveryCode != null &&
                            widget.onCompleteRecovery != null) ...<Widget>[
                          const SizedBox(height: 16),
                          TextButton(
                            key: DeviceRegistrationKeys.recoveryLink,
                            onPressed: _registering ? null : () => setState(() {
                              _recoveryMode = true;
                              _error = null;
                            }),
                            child: Text(
                              "Can't access your trusted device?",
                              style: AppTypography.body.copyWith(
                                color: AppColors.primaryEnd,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}