import 'package:flutter/material.dart';

import '../../data/orbit_identity_client.dart';
import 'verify_otp_screen.dart';

/// Connects the existing approved VerifyOtpScreen to the Laravel auth API.
/// This controller owns no separate OTP design, text field or card.
class OrbitOtpVerificationController extends StatefulWidget {
  const OrbitOtpVerificationController({
    required this.recipient,
    required this.onVerified,
    this.password,
    this.identityClient,
    super.key,
  });

  final String recipient;
  final String? password;
  final VoidCallback onVerified;
  final OrbitIdentityClient? identityClient;

  @override
  State<OrbitOtpVerificationController> createState() =>
      _OrbitOtpVerificationControllerState();
}

class _OrbitOtpVerificationControllerState
    extends State<OrbitOtpVerificationController> {
  late final OrbitIdentityClient _identity =
      widget.identityClient ?? OrbitIdentityClient.instance;
  bool _sent = false;
  bool _sending = false;
  bool _verifying = false;
  bool _verified = false;
  int _sendRevision = 0;
  String? _error;

  String get _channel => widget.recipient.contains('@') ? 'email' : 'sms';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestCode();
    });
  }

  Future<void> _requestCode() async {
    if (_sending || _verifying || _verified) return;
    setState(() {
      _sending = true;
      _sent = false;
      _error = null;
    });
    try {
      // Password-based login still requires the exact same OTP verification
      // and device trust; no session is granted after password entry alone.
      if (widget.password != null) {
        await _identity.requestPasswordCode(widget.recipient, widget.password!);
      } else {
        await _identity.requestCode(_channel, widget.recipient);
      }
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sendRevision++;
      });
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not send the verification code. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode(String code) async {
    if (!_sent || _sending || _verifying || _verified) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _identity.verifyCode(_channel, widget.recipient, code);
      if (!mounted) return;
      _verified = true;
      widget.onVerified();
    } on OrbitIdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not verify the code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VerifyOtpScreen(
      key: ValueKey('orbit_otp_verification_$_sendRevision'),
      recipient: widget.recipient,
      onVerifyCode: (code) { _verifyCode(code); },
      initialCountdownSeconds: 60,
      codeDispatched: _sent,
      isRequesting: _sending,
      isVerifying: _verifying,
      errorMessage: _error,
      onResendCode: _requestCode,
      onChangeDestination: () => Navigator.of(context).maybePop(),
    );
  }
}
