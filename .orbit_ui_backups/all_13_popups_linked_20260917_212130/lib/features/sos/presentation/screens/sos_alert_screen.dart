import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/sos_models.dart';
import '../widgets/sos_header.dart';
import '../widgets/sos_quick_actions.dart';
import '../widgets/sos_trigger.dart';

class SosAlertScreen extends StatefulWidget {
  const SosAlertScreen({
    this.onAlertTriggered,
    this.onEmergencyContacts,
    this.onShareLocation,
    this.onRecordAudio,
    this.onCallEmergency,
    super.key,
  });

  factory SosAlertScreen.demo() => const SosAlertScreen();

  final ValueChanged<SosAlertSubmission>? onAlertTriggered;
  final VoidCallback? onEmergencyContacts;
  final VoidCallback? onShareLocation;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onCallEmergency;

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  static const Color _background = Color(0xFF0D0F20);

  void _pop() {
    Navigator.of(context).maybePop();
  }

  void _handleTriggered(SosAlertSubmission submission) {
    widget.onAlertTriggered?.call(submission);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS alert sent to your circle'),
        duration: Duration(seconds: 2),
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
        _showDemoMessage('Emergency audio recording');
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
