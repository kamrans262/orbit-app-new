import 'package:flutter/material.dart';

@immutable
class QuickActionData {
  const QuickActionData({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
}

@immutable
class ParticipantData {
  const ParticipantData({
    required this.id,
    required this.name,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String imagePath;
}

@immutable
class UpcomingPlanData {
  const UpcomingPlanData({
    required this.id,
    required this.title,
    required this.schedule,
    required this.participants,
  });

  final String id;
  final String title;
  final String schedule;
  final List<ParticipantData> participants;
}

@immutable
class PromoBannerData {
  const PromoBannerData({
    required this.id,
    required this.backgroundImagePath,
    required this.logoImagePath,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String backgroundImagePath;
  final String logoImagePath;
  final String title;
  final String subtitle;
}

@immutable
class FavoritePersonData {
  const FavoritePersonData({
    required this.id,
    required this.name,
    required this.status,
    required this.imagePath,
    this.isFavorite = true,
  });

  final String id;
  final String name;
  final String status;
  final String imagePath;
  final bool isFavorite;
}

@immutable
class MomentData {
  const MomentData({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String timeLabel;
  final String imagePath;
}
