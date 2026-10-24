import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_friend_requests_screen.dart';
import 'package:orbit_ui/features/friends/presentation/widgets/friend_request_segmented_control.dart';

class _FriendRequestRepository extends OrbitSocialRepository {
  final List<String> readDirections = <String>[];

  @override
  Future<OrbitFriendPage<OrbitFriendRequest>> requests(
      String direction, {int page = 1}) async {
    readDirections.add(direction);
    return OrbitFriendPage<OrbitFriendRequest>(
      page: page,
      hasMore: false,
      items: <OrbitFriendRequest>[
        OrbitFriendRequest(
          id: direction == 'incoming' ? 'received-1' : 'sent-1',
          person: OrbitPerson(
            id: direction == 'incoming' ? 'sender-1' : 'recipient-1',
            name: direction == 'incoming' ? 'Sender A' : 'Recipient B',
            username: direction == 'incoming' ? 'sender_a' : 'recipient_b',
          ),
        ),
      ],
    );
  }
}

void main() {
  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('Received and Sent keep full width at ${size.width}x${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FriendRequestRepository();

      await tester.pumpWidget(MaterialApp(
        home: OrbitFriendRequestsScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      final segment = find.byKey(OrbitFriendRequestsKeys.segmentedControl);
      final received = find.byKey(FriendRequestSegmentedControlKeys.received);
      final sent = find.byKey(FriendRequestSegmentedControlKeys.sent);
      final original = tester.getSize(segment);
      expect(original.width, moreOrLessEquals(size.width - 40));
      expect(original.height, FriendRequestSegmentedControl.height);
      expect(tester.getSize(received).width,
          moreOrLessEquals(original.width / 2));
      expect(tester.getSize(sent).width,
          moreOrLessEquals(original.width / 2));

      // Confirm the header matches the approved compact Orbit settings header.
      final back = tester.widget<AppCircularIconButton>(
          find.byKey(OrbitFriendRequestsKeys.backButton));
      expect(back.size, 30);
      expect(back.iconSize, 24);
      final title = tester.widget<Text>(
          find.byKey(OrbitFriendRequestsKeys.title));
      expect(title.style?.fontSize, 16);

      expect(find.text('Sender A'), findsOneWidget);
      expect(find.text('Recipient B'), findsNothing);
      await tester.tap(sent);
      await tester.pumpAndSettle();

      expect(tester.getSize(segment), original);
      expect(tester.getSize(received).width,
          moreOrLessEquals(original.width / 2));
      expect(tester.getSize(sent).width,
          moreOrLessEquals(original.width / 2));
      expect(find.text('Recipient B'), findsOneWidget);
      expect(find.text('Sender A'), findsNothing);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(repo.readDirections, <String>['incoming', 'outgoing']);
      expect(tester.takeException(), isNull);

      await tester.tap(received);
      await tester.pumpAndSettle();
      expect(tester.getSize(segment), original);
      expect(find.text('Sender A'), findsOneWidget);
      expect(repo.readDirections,
          <String>['incoming', 'outgoing', 'incoming']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Person Detail outgoing entry keeps Sent selected at full width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FriendRequestRepository();
    await tester.pumpWidget(MaterialApp(
      home: OrbitFriendRequestsScreen(
        repository: repo,
        initialDirection: 'outgoing',
      ),
    ));
    await tester.pumpAndSettle();

    final segment = tester.widget<FriendRequestSegmentedControl>(
        find.byType(FriendRequestSegmentedControl));
    expect(segment.value, 'outgoing');
    expect(tester.getSize(
        find.byKey(OrbitFriendRequestsKeys.segmentedControl)).width, 350);
    expect(find.text('Recipient B'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
    expect(repo.readDirections, <String>['outgoing']);
    expect(tester.takeException(), isNull);
  });
}
