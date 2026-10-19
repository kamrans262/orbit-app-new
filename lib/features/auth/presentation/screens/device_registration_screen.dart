import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../widgets/auth_card.dart';

abstract final class DeviceRegistrationKeys {
  static const heading = Key('device_registration_heading');
  static const back = Key('device_registration_back');
  static const deviceCard = Key('device_registration_device_card');
  static const action = Key('device_registration_action');
  static const error = Key('device_registration_error');
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
    this.deviceName = 'This device',
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final Future<bool> Function()? onRegisterDevice;
  final String deviceName;

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  bool _registering = false;
  String? _error;

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
      final registered = await register();
      if (!mounted) return;
      if (registered) {
        widget.onContinue();
      } else {
        setState(
          () => _error = 'Device registration was not completed. Try again.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('OrbitIdentityException: ', ''));
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
                      SizedBox(height: compact ? 26 : 42),
                      SizedBox(
                        key: DeviceRegistrationKeys.action,
                        child: AppPrimaryButton(
                          label: _registering
                              ? 'Registering…'
                              : preview
                              ? 'Continue'
                              : 'Register Device',
                          enabled: !_registering,
                          onPressed: () {
                            _handleAction();
                          },
                        ),
                      ),
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
