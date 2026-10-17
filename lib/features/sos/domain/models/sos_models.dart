import 'package:flutter/foundation.dart';

@immutable
class SosAlertSubmission {
  const SosAlertSubmission({required this.heldFor, required this.sentAt});

  final Duration heldFor;
  final DateTime sentAt;
}

enum SosQuickActionType {
  emergencyContacts,
  shareLocation,
  recordAudio,
  callEmergency,
}
