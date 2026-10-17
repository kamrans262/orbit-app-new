import 'package:flutter/material.dart';

enum ExploreViewState { loading, populated, empty, error }

@immutable
class ExploreCategoryData {
  const ExploreCategoryData({
    required this.id,
    required this.title,
    required this.count,
    required this.iconAsset,
  });

  final String id;
  final String title;
  final int count;
  final String iconAsset;
}

@immutable
class ExploreMeetupData {
  const ExploreMeetupData({
    required this.id,
    required this.title,
    required this.image,
    required this.dateTimeLabel,
    required this.secondaryLabel,
    required this.attendeeAvatars,
    required this.attendeeCount,
    this.isSaved = false,
    this.isJoined = false,
  });

  final String id;
  final String title;
  final String image;
  final String dateTimeLabel;
  final String secondaryLabel;
  final List<String?> attendeeAvatars;
  final int attendeeCount;
  final bool isSaved;
  final bool isJoined;

  ExploreMeetupData copyWith({
    bool? isSaved,
    bool? isJoined,
  }) {
    return ExploreMeetupData(
      id: id,
      title: title,
      image: image,
      dateTimeLabel: dateTimeLabel,
      secondaryLabel: secondaryLabel,
      attendeeAvatars: attendeeAvatars,
      attendeeCount: attendeeCount,
      isSaved: isSaved ?? this.isSaved,
      isJoined: isJoined ?? this.isJoined,
    );
  }
}
