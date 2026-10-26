import 'dart:typed_data';
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
    this.location,
    required this.participants,
  });

  final String id;
  final String title;
  final String schedule;
  final String? location;
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
    this.isFavorite = false,
    this.isOnline,
  });

  final String id;
  final String name;
  final String status;
  final String imagePath;
  final bool isFavorite;
  final bool? isOnline;

  FavoritePersonData copyWith({
    String? id,
    String? name,
    String? status,
    String? imagePath,
    bool? isFavorite,
    bool? isOnline,
  }) {
    return FavoritePersonData(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      isFavorite: isFavorite ?? this.isFavorite,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

@immutable
class MomentData {
  const MomentData({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.imagePath,
    this.senderAvatarPath,
    this.isSenderOnline,
    this.encryptedImageBytes,
    this.mediaKind = 'image',
  });

  final String id;
  final String name;
  final String timeLabel;
  final String imagePath;
  final String? senderAvatarPath;
  final bool? isSenderOnline;
  final Uint8List? encryptedImageBytes;
  final String mediaKind;
}

/// Real M5 Circle metadata; not an M4 friend/avatar surrogate.
@immutable
class HomeCircleSummaryData {
  const HomeCircleSummaryData({required this.id,required this.name,
    required this.memberCount,required this.role,this.colorValue});
  final String id,name,role;
  final int memberCount;
  final String? colorValue;
}
