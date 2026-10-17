import 'package:flutter/foundation.dart';

@immutable
class MomentAuthorData {
  const MomentAuthorData({
    required this.id,
    required this.name,
    this.imagePath,
  });

  final String id;
  final String name;
  final String? imagePath;
}

@immutable
class MomentStoryData {
  const MomentStoryData({
    required this.id,
    required this.name,
    this.imagePath,
    this.isAddStory = false,
  });

  final String id;
  final String name;
  final String? imagePath;
  final bool isAddStory;
}

enum MomentFeedItemType { imagePost, promo, textPost, futureVideoPost }

@immutable
abstract class MomentFeedItem {
  const MomentFeedItem({required this.id});

  final String id;
  MomentFeedItemType get type;
}

@immutable
class MomentImageFeedItem extends MomentFeedItem {
  const MomentImageFeedItem({
    required super.id,
    required this.author,
    required this.timeLabel,
    required this.imagePath,
    required this.title,
    required this.location,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  final MomentAuthorData author;
  final String timeLabel;
  final String? imagePath;
  final String title;
  final String location;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isBookmarked;

  @override
  MomentFeedItemType get type => MomentFeedItemType.imagePost;
}

@immutable
class MomentPromoFeedItem extends MomentFeedItem {
  const MomentPromoFeedItem({
    required super.id,
    required this.backgroundImagePath,
    required this.logoImagePath,
    required this.title,
    required this.subtitle,
  });

  final String backgroundImagePath;
  final String logoImagePath;
  final String title;
  final String subtitle;

  @override
  MomentFeedItemType get type => MomentFeedItemType.promo;
}

@immutable
class MomentTextFeedItem extends MomentFeedItem {
  const MomentTextFeedItem({
    required super.id,
    required this.author,
    required this.timeLabel,
    required this.text,
  });

  final MomentAuthorData author;
  final String timeLabel;
  final String text;

  @override
  MomentFeedItemType get type => MomentFeedItemType.textPost;
}

@immutable
class MomentFutureVideoFeedItem extends MomentFeedItem {
  const MomentFutureVideoFeedItem({
    required super.id,
    required this.author,
    required this.timeLabel,
    required this.caption,
    this.thumbnailPath,
  });

  final MomentAuthorData author;
  final String timeLabel;
  final String caption;
  final String? thumbnailPath;

  @override
  MomentFeedItemType get type => MomentFeedItemType.futureVideoPost;
}

enum MomentsViewState { loading, empty, error, populated }
