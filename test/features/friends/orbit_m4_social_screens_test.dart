import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';
import 'package:orbit_ui/features/friends/data/orbit_friend_snapshot.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_person_screen.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_live_friends_screen.dart';
import 'package:orbit_ui/features/friends/presentation/screens/friends_screen.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_discover_friends_screen.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/features/home/presentation/widgets/favorite_person_tile.dart';
import 'package:orbit_ui/features/welcome/domain/models/nearby_person.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/nearby_person_tile.dart';
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


class _RequestSocial extends OrbitSocialRepository {
  String? lastDirection;

  @override
  Future<OrbitPerson> preview(String id) async =>
      const OrbitPerson(
        id: 'person-01', name: 'Ayesha', username: 'ayesha',
        relationship: 'outgoing_pending',
      );

  @override
  Future<OrbitFriendPage<OrbitFriendRequest>> requests(
      String direction, {int page = 1}) async {
    lastDirection = direction;
    return const OrbitFriendPage<OrbitFriendRequest>(
      page: 1, hasMore: false, items: <OrbitFriendRequest>[],
    );
  }
}

class _OfflineSocial extends _FakeSocial {
  bool disconnected = true;

  @override
  Future<OrbitFriendPage<OrbitPerson>> friends({int page = 1}) async {
    if (disconnected) throw OrbitIdentityException('Connection unavailable.');
    return super.friends(page: page);
  }
}

class _MemoryFriendSnapshot extends OrbitFriendSnapshotStore {
  @override
  Future<OrbitFriendSnapshot?> read() async => OrbitFriendSnapshot(
    savedAt: DateTime.now(),
    people: const <OrbitPerson>[
      OrbitPerson(id: 'cached-1', name: 'Saved Friend', username: 'saved'),
    ],
  );

  @override
  Future<void> save(List<OrbitPerson> people) async {}

  @override
  Future<void> clear() async {}
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
    expect(find.byKey(FriendsKeys.searchButton), findsOneWidget);
    expect(find.bySemanticsLabel('Friend requests'), findsOneWidget);
    expect(find.byType(AppCircularIconButton), findsWidgets);
    // The Find Friends icon now uses the former Friend Requests icon.
    final findFriends = tester.widget<AppCircularIconButton>(
        find.byKey(FriendsKeys.searchButton));
    expect(findFriends.icon, Icons.person_add_alt_outlined);
    // Requests has a distinct incoming-mail icon.
    final requests = tester.widget<AppCircularIconButton>(
        find.byWidgetPredicate((widget) =>
            widget is AppCircularIconButton &&
            widget.semanticLabel == 'Friend requests'));
    expect(requests.icon, Icons.mark_email_unread_outlined);
    // Live Friends now displays the exact same original person card as
    // Circle Friend Details, including the read-only favorite heart.
    expect(find.byType(FavoritePersonTile), findsOneWidget);
    final favorite = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(FriendsKeys.row('person-01')),
          matching: find.byType(IconButton),
        ));
    expect(favorite.onPressed, isNull);
    expect(find.byIcon(Icons.person_search_outlined), findsNothing);
    expect(repo.friendReads, 1);
    await tester.tap(find.byKey(FriendsKeys.searchButton));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitDiscoverFriendsScreen), findsOneWidget);
    expect(find.text('Find Friends'), findsOneWidget);
  });


  testWidgets('Find Friends restores original nearby section without fake users',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: OrbitDiscoverFriendsScreen(repository: _FakeSocial()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Near By People'), findsOneWidget);
    expect(find.textContaining('Nearby people are not available yet'),
        findsOneWidget);
    expect(find.byType(NearbyPersonTile), findsNothing);
    expect(find.text('Emma'), findsNothing);
    expect(find.text('2.1 km'), findsNothing);
    expect(find.text('You can search by name without sharing contacts.'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Find Friends reuses Invite People tiles for verified nearby data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: OrbitDiscoverFriendsScreen(
        repository: _FakeSocial(),
        nearbyPeople: const <NearbyPerson>[
          NearbyPerson(id: 'verified-1', name: 'Verified Person',
              distance: '1.4 km', imageAsset: ''),
          // A demo row without stable identity must never be presented live.
          NearbyPerson(name: 'Unverified Demo', distance: '2.1 km',
              imageAsset: 'assets/Emma.png'),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Near By People'), findsOneWidget);
    expect(find.byType(NearbyPersonTile), findsOneWidget);
    expect(find.text('Verified Person'), findsOneWidget);
    expect(find.text('1.4 km'), findsOneWidget);
    expect(find.text('Unverified Demo'), findsNothing);
    expect(find.byKey(const Key('find_friends_nearby_list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invitation code entry uses approved popup and safe controller lifetime',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OrbitDiscoverFriendsScreen(repository: _FakeSocial()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter Invite Code'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_popup_card')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'CODE123');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbit_popup_card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Person Detail pending request opens the authoritative Sent tab',
      (tester) async {
    final repo = _RequestSocial();
    await tester.pumpWidget(MaterialApp(home: OrbitPersonScreen(
      person: const OrbitPerson(id: 'person-01', name: 'Ayesha', username: 'ayesha'),
      repository: repo,
    )));
    await tester.pumpAndSettle();
    // Person Detail is a lazy ListView. Scroll to build the relationship
    // action before trying to tap it in a compact widget-test viewport.
    await tester.scrollUntilVisible(find.text('Manage sent request'), 160,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Manage sent request'));
    await tester.pumpAndSettle();
    expect(find.text('Friend Requests'), findsOneWidget);
    expect(repo.lastDirection, 'outgoing');
  });

  testWidgets('Offline Friends remains read-only and refreshes on resume',
      (tester) async {
    final repo = _OfflineSocial();
    await tester.pumpWidget(MaterialApp(home: OrbitLiveFriendsScreen(
      repository: repo, snapshotStore: _MemoryFriendSnapshot(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Saved Friend'), findsOneWidget);
    expect(find.textContaining('OFFLINE'), findsOneWidget);
    await tester.tap(find.byKey(FriendsKeys.searchButton));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitDiscoverFriendsScreen), findsNothing);
    expect(find.text('Reconnect to find friends.'), findsOneWidget);
    repo.disconnected = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Ayesha'), findsOneWidget);
    expect(find.textContaining('OFFLINE'), findsNothing);
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
