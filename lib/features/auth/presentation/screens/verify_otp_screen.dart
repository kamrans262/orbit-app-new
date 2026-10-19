import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_otp_input.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_otp_layout_metrics.dart';
import '../widgets/auth_screen_layout.dart';

abstract final class VerifyOtpKeys {
  static const card = Key('verify_otp_card');
  static const heading = Key('verify_otp_heading');
  static const subtitle = Key('verify_otp_subtitle');
  static const otpInput = Key('verify_otp_input');
  static const actionButton = Key('verify_otp_action_button');
}

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    required this.recipient,
    required this.onVerifyCode,
    this.initialCountdownSeconds = 23,
    this.codeDispatched = true,
    this.isRequesting = false,
    this.isVerifying = false,
    this.errorMessage,
    this.completeActionLabel = 'Verify Code',
    this.onResendCode,
    this.onChangeDestination,
    super.key,
  });

  final String recipient;
  final ValueChanged<String> onVerifyCode;
  final int initialCountdownSeconds;
  final bool codeDispatched;
  final bool isRequesting;
  final bool isVerifying;
  final String? errorMessage;
  final String completeActionLabel;
  final VoidCallback? onResendCode;
  final VoidCallback? onChangeDestination;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  Timer? _countdownTimer;
  late int _secondsRemaining;
  String _code = '';

  bool get _isComplete => _code.length == 6;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialCountdownSeconds.clamp(0, 3599).toInt();
    if (_secondsRemaining > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          return;
        }
        if (_secondsRemaining <= 1) {
          timer.cancel();
          setState(() {
            _secondsRemaining = 0;
          });
          return;
        }
        setState(() {
          _secondsRemaining--;
        });
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _countdownLabel {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final minuteText = minutes.toString().padLeft(2, '0');
    final secondText = seconds.toString().padLeft(2, '0');
    return 'Send Code ($minuteText:$secondText)';
  }

  void _handleCodeChanged(String value) {
    if (_code == value) {
      return;
    }
    setState(() {
      _code = value;
    });
  }

  void _submit() {
    if (_isComplete && widget.codeDispatched && !widget.isVerifying &&
        !widget.isRequesting) {
      widget.onVerifyCode(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenLayout(
      child: AuthCard(
        cardKey: VerifyOtpKeys.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AuthHeader(
              heading: 'Enter the Code',
              subtitle: widget.codeDispatched
                  ? 'We sent a 6-digit code to\n${widget.recipient}'
                  : 'Verification code for\n${widget.recipient}',
              headingKey: VerifyOtpKeys.heading,
              subtitleKey: VerifyOtpKeys.subtitle,
            ),
            const SizedBox(height: AuthOtpLayoutMetrics.subtitleToOtpGap),
            AppOtpInput(
              key: VerifyOtpKeys.otpInput,
              onChanged: _handleCodeChanged,
              enabled: widget.codeDispatched && !widget.isVerifying && !widget.isRequesting,
            ),
            const SizedBox(height: AuthOtpLayoutMetrics.otpToActionGap),
            SizedBox(
              key: VerifyOtpKeys.actionButton,
              child: AppPrimaryButton(
                label: widget.isRequesting
                    ? 'Sending Code…'
                    : widget.isVerifying
                        ? 'Verifying…'
                        : _isComplete
                            ? widget.completeActionLabel
                            : _countdownLabel,
                enabled: _isComplete && widget.codeDispatched &&
                    !widget.isRequesting && !widget.isVerifying,
                onPressed: _submit,
              ),
            ),
            if (widget.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                widget.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: Colors.red),
              ),
            ],
            if (widget.onResendCode != null &&
                (!widget.codeDispatched || _secondsRemaining == 0)) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.isRequesting || widget.isVerifying
                    ? null
                    : widget.onResendCode,
                child: Text(
                  widget.codeDispatched ? 'Resend Code' : 'Try Again',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryEnd, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (widget.onChangeDestination != null) ...<Widget>[
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.isVerifying || widget.isRequesting
                    ? null
                    : widget.onChangeDestination,
                child: Text(
                  'Change destination',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryEnd, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
