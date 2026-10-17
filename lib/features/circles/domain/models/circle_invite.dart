import 'package:flutter/foundation.dart';

enum CircleInviteStatus { pending, accepted, declined }

enum CircleInviteTab { sent, pending, accepted }

enum CircleInviteViewState { loading, loaded, empty, error }

@immutable
class CircleInvite {
  const CircleInvite({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String avatarUrl;
  final CircleInviteStatus status;
  final DateTime createdAt;

  CircleInvite copyWith({
    String? id,
    String? userId,
    String? userName,
    String? avatarUrl,
    CircleInviteStatus? status,
    DateTime? createdAt,
  }) {
    return CircleInvite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static final List<CircleInvite> demoSent = <CircleInvite>[
    CircleInvite(
      id: 'sent-emma',
      userId: 'emma',
      userName: 'Emma',
      avatarUrl: 'assets/Emma.png',
      status: CircleInviteStatus.pending,
      createdAt: DateTime(2026, 9, 17),
    ),
    CircleInvite(
      id: 'sent-olivia',
      userId: 'olivia',
      userName: 'Olivia',
      avatarUrl: 'assets/Sophia.png',
      status: CircleInviteStatus.accepted,
      createdAt: DateTime(2026, 9, 16),
    ),
    CircleInvite(
      id: 'sent-oliviia',
      userId: 'oliviia',
      userName: 'Olivia',
      avatarUrl: 'assets/Mike.png',
      status: CircleInviteStatus.declined,
      createdAt: DateTime(2026, 9, 15),
    ),
  ];

  static final List<CircleInvite> demoPending = <CircleInvite>[
    CircleInvite(
      id: 'pending-emma',
      userId: 'emma',
      userName: 'Emma',
      avatarUrl: 'assets/Emma.png',
      status: CircleInviteStatus.pending,
      createdAt: DateTime(2026, 9, 17),
    ),
    CircleInvite(
      id: 'pending-oliviia',
      userId: 'oliviia',
      userName: 'Olivia',
      avatarUrl: 'assets/Mike.png',
      status: CircleInviteStatus.pending,
      createdAt: DateTime(2026, 9, 16),
    ),
  ];

  static final List<CircleInvite> demoAccepted = <CircleInvite>[
    CircleInvite(
      id: 'accepted-olivia',
      userId: 'olivia',
      userName: 'Olivia',
      avatarUrl: 'assets/Sophia.png',
      status: CircleInviteStatus.accepted,
      createdAt: DateTime(2026, 9, 16),
    ),
  ];
}

@immutable
class CircleInviteTabData {
  const CircleInviteTabData({
    this.state = CircleInviteViewState.loaded,
    this.invites = const <CircleInvite>[],
    this.errorMessage,
  });

  final CircleInviteViewState state;
  final List<CircleInvite> invites;
  final String? errorMessage;
}
