import 'package:flutter/foundation.dart';

@immutable
class UserPrivacyEntry {
  const UserPrivacyEntry({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isBlocked = false,
  });

  final String id;
  final String name;

  /// May be a remote URL once the backend is connected. Demo entries use
  /// existing Orbit asset paths so no new image assets are introduced here.
  final String avatarUrl;
  final bool isBlocked;

  UserPrivacyEntry copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isBlocked,
  }) {
    return UserPrivacyEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  static const List<UserPrivacyEntry> demoUsers = <UserPrivacyEntry>[
    UserPrivacyEntry(
      id: 'emma',
      name: 'Emma',
      avatarUrl: 'assets/Emma.png',
    ),
    UserPrivacyEntry(
      id: 'olivia',
      name: 'Olivia',
      avatarUrl: 'assets/Sophia.png',
    ),
    UserPrivacyEntry(
      id: 'oliviia',
      name: 'Oliviia',
      avatarUrl: 'assets/Mike.png',
    ),
  ];
}
