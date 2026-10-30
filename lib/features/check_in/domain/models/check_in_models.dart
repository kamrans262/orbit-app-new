import 'package:flutter/material.dart';

enum CheckInInteractionType { tap, hold }

@immutable
class CheckInActivityData {
  const CheckInActivityData({
    required this.id,
    required this.label,
    required this.iconAsset,
    required this.backgroundColor,
    required this.iconColor,
    this.isMore = false,
  });

  final String id;
  final String label;
  final String iconAsset;
  final Color backgroundColor;
  final Color iconColor;
  final bool isMore;
}

@immutable
class CheckInSubmission {
  const CheckInSubmission({
    required this.activityId,
    required this.activityName,
    required this.sentAt,
    required this.interactionType,
    this.customText,
  });

  final String activityId;
  final String activityName;
  final DateTime sentAt;
  final CheckInInteractionType interactionType;
  final String? customText;
}
