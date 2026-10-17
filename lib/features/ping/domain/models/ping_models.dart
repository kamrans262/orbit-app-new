import 'package:flutter/material.dart';

@immutable
class PingOption {
  const PingOption({
    required this.id,
    required this.emoji,
    required this.title,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String id;
  final String emoji;
  final String title;
  final Color backgroundColor;
  final Color foregroundColor;
}

@immutable
class PingSubmission {
  const PingSubmission({
    required this.type,
    required this.message,
    required this.sentAt,
    this.recipientOrCircleId,
  });

  final String type;
  final String message;
  final DateTime sentAt;
  final String? recipientOrCircleId;
}
