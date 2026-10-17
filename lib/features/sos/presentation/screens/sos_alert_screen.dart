import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import 'sos_responder_map_screen.dart';
import '../../domain/models/sos_models.dart';
import '../widgets/sos_header.dart';
import '../widgets/sos_quick_actions.dart';
import '../widgets/sos_trigger.dart';
import '../../../../core/popups/orbit_popup_variants.dart';

class SosAlertScreen extends StatefulWidget {
  const SosAlertScreen({
    this.onAlertTriggered,
    this.onActivateSos,
    this.onEmergencyContacts,
    this.onShareLocation,
    this.onRecordAudio,
    this.onCallEmergency,
    super.key,
  });

  factory SosAlertScreen.demo() => const SosAlertScreen();

  final ValueChanged<SosAlertSubmission>? onAlertTriggered;

  /// The future backend must return a server-confirmed session; null means no confirmation.
  /// The existing onAlertTriggered callback is retained for older clients.
  final Future<SosResponderSession?> Function(SosAlertSubmission)?
  onActivateSos;
  final VoidCallback? onEmergencyContacts;
  final VoidCallback? onShareLocation;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onCallEmergency;

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  static const Color _background = Color(0xFF0D0F20);
  bool _activationBusy = false;

  void _pop() {
    Navigator.of(context).maybePop();
  }

  void _handleTriggered(SosAlertSubmission submission) {
    if (_activationBusy) return;
    unawaited(_activateSos(submission));
  }

  Future<void> _activateSos(SosAlertSubmission submission) async {
    if (_activationBusy || !mounted) return;
    setState(() => _activationBusy = true);
    try {
      final activate = widget.onActivateSos;
      if (activate == null) {
        widget.onAlertTriggered?.call(submission);
        if (mounted) {
          _sosNotice(
            'SOS delivery is not confirmed. No alert is verified as sent. This UI-only build does not contact responders.',
          );
        }
        return;
      }
      final session = await activate(submission);
      if (!mounted) return;
      if (session == null ||
          !session.serverConfirmed ||
          session.id.trim().isEmpty) {
        _sosNotice(
          'SOS was not confirmed by the service. Please use your local emergency services if you need immediate help.',
        );
        return;
      }
      await Navigator.of(context).push<void>(
        AppFadeSlidePageRoute<void>(
          builder: (_) => SosResponderMapScreen(session: session),
        ),
      );
    } catch (_) {
      if (mounted) {
        _sosNotice(
          'SOS delivery could not be confirmed. Please use your local emergency services if you need immediate help.',
        );
      }
    } finally {
      if (mounted) setState(() => _activationBusy = false);
    }
  }

  void _sosNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
    );
  }

  void _openResponderPreview() {
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => const SosResponderMapScreen(),
      ),
    );
  }

  void _handleQuickAction(SosQuickActionType type) {
    switch (type) {
      case SosQuickActionType.emergencyContacts:
        if (widget.onEmergencyContacts != null) {
          widget.onEmergencyContacts!();
          return;
        }
        _showDemoMessage('Emergency contacts');
      case SosQuickActionType.shareLocation:
        if (widget.onShareLocation != null) {
          widget.onShareLocation!();
          return;
        }
        _showDemoMessage('Location sharing');
      case SosQuickActionType.recordAudio:
        if (widget.onRecordAudio != null) {
          widget.onRecordAudio!();
          return;
        }
        unawaited(
          showMicrophonePermissionPopup(
            context,
            onAllow: () => _showDemoMessage('Emergency audio recording'),
            onNotNow: () {},
          ),
        );
        return;
      case SosQuickActionType.callEmergency:
        if (widget.onCallEmergency != null) {
          widget.onCallEmergency!();
          return;
        }
        _showDemoMessage('Emergency call');
    }
  }

  void _showDemoMessage(String action) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is ready for backend/device integration.'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: const ValueKey<String>('sos-alert-screen'),
        backgroundColor: _background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 42).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SosHeader(onBack: _pop, onClose: _pop),
                      const SizedBox(height: 60),
                      Align(
                        alignment: Alignment.center,
                        child: SosTrigger(onTriggered: _handleTriggered),
                      ),
                      const SizedBox(height: 50),
                      const Text(
                        'Hold for 3 seconds to alert your circle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
                          color: Color(0xFF9EA3AB),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _DotsIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        '3 second hold',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Color(0xA6FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SosQuickActions(onAction: _handleQuickAction),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        key: const ValueKey<String>(
                          'sos-preview-responder-map',
                        ),
                        onPressed: _openResponderPreview,
                        icon: const Icon(
                          Icons.map_outlined,
                          color: Colors.white70,
                        ),
                        label: const Text(
                          'Preview Responder Map (UI only)',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Preview does not activate SOS, alert contacts, or share your location.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          height: 1.4,
                          color: Color(0xFF9EA3AB),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _Dot(),
        SizedBox(width: 10),
        _Dot(),
        SizedBox(width: 10),
        _Dot(),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2A2C31),
        ),
      ),
    );
  }
}
