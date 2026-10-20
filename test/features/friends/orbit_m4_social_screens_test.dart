import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_live_friends_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/orbit_live_blocked_users_screen.dart';

class _FakeSocial extends OrbitSocialRepository {
  bool blocked = true;
  int friendReads = 0;

  @override
  Future<OrbitFriendPage<OrbitPerson>> friends({int page = 1}) async {
    friendReads++;
    return const OrbitFriendPage(
      page: 1, hasMore: false, items: [
        OrbitPerson(id: 'person-01', name: 'Ayesha', username: 'ayesha', relationship: 'friend'),
      ],
    );
  }

  @override
  Future<OrbitFriendPage<OrbitPerson>> blocks({int page = 1}) async {
    return OrbitFriendPage(
      page:1, hasMore:false,
      items:blocked
          ? const [OrbitPerson(id:'person-02',name:'Omar',username:'omar')]
          : const [],
    );
  }

  @override
  Future<void> unblock(String id) async {
    if (id == 'person-02') blocked = false;
  }
}

void main() {
  testWidgets('Live Friends shows real records and never demo people',
      (tester) async {
    final repo = _FakeSocial();
    await tester.pumpWidget(MaterialApp(home:OrbitLiveFriendsScreen(repository:repo)));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha'),findsOneWidget);
    expect(find.text('@ayesha'),findsOneWidget);
    expect(find.text('Emma'),findsNothing);
    expect(find.byTooltip('Find friends'),findsOneWidget);
    expect(find.byTooltip('Friend requests'),findsOneWidget);
    expect(repo.friendReads,1);
  });

  testWidgets('Live blocking waits for server and clears account on success',
      (tester) async {
    final repo = _FakeSocial();
    await tester.pumpWidget(MaterialApp(home:OrbitLiveBlockedUsersScreen(repository:repo)));
    await tester.pumpAndSettle();
    expect(find.text('Omar'),findsOneWidget);
    expect(find.text('Emma'),findsNothing);
    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();
    expect(repo.blocked,isFalse);
    expect(find.text('Omar'),findsNothing);
  });
}
