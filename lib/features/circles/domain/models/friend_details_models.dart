import 'package:flutter/foundation.dart';

enum FriendDetailsViewState { loading, loaded, error }

enum FriendDetailsSegment { circle, group }

@immutable
class FriendMemberData {
  const FriendMemberData({
    required this.id,
    required this.name,
    required this.status,
    required this.imagePath,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
  });

  final String id;
  final String name;
  final String status;
  final String? imagePath;
  final bool isFavorite;
  final VoidCallback? onTap;
  final ValueChanged<FriendMemberData>? onFavoriteTap;

  FriendMemberData copyWith({
    String? id,
    String? name,
    String? status,
    String? imagePath,
    bool? isFavorite,
    VoidCallback? onTap,
    ValueChanged<FriendMemberData>? onFavoriteTap,
  }) {
    return FriendMemberData(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      isFavorite: isFavorite ?? this.isFavorite,
      onTap: onTap ?? this.onTap,
      onFavoriteTap: onFavoriteTap ?? this.onFavoriteTap,
    );
  }
}

@immutable
class CircleGroupData {
  const CircleGroupData({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.memberAvatars,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
  });

  final String id;
  final String name;
  final int memberCount;
  final List<String?> memberAvatars;
  final bool isFavorite;
  final VoidCallback? onTap;
  final ValueChanged<CircleGroupData>? onFavoriteTap;

  CircleGroupData copyWith({
    String? id,
    String? name,
    int? memberCount,
    List<String?>? memberAvatars,
    bool? isFavorite,
    VoidCallback? onTap,
    ValueChanged<CircleGroupData>? onFavoriteTap,
  }) {
    return CircleGroupData(
      id: id ?? this.id,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      memberAvatars: memberAvatars ?? this.memberAvatars,
      isFavorite: isFavorite ?? this.isFavorite,
      onTap: onTap ?? this.onTap,
      onFavoriteTap: onFavoriteTap ?? this.onFavoriteTap,
    );
  }
}
