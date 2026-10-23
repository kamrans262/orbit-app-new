import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_discover_friends_screen.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';

void main() {
  testWidgets('Home Find friends header button matches Orbit and opens discovery',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pumpAndSettle();

    final findFriends = find.byKey(HomeKeys.findFriendsButton);
    final notifications = find.byKey(HomeKeys.notificationButton);
    expect(findFriends, findsOneWidget);
    expect(notifications, findsOneWidget);

    final friendsIcon = tester.widget<AppCircularIconButton>(findFriends);
    final notificationsIcon =
        tester.widget<AppCircularIconButton>(notifications);
    expect(friendsIcon.size, notificationsIcon.size);
    expect(friendsIcon.iconSize, notificationsIcon.iconSize);
    expect(friendsIcon.iconGradient, isNotNull);
    expect(tester.getTopLeft(findFriends).dx,
        lessThan(tester.getTopLeft(notifications).dx));
    expect(tester.takeException(), isNull);

    await tester.tap(findFriends);
    await tester.pumpAndSettle();
    expect(find.byType(OrbitDiscoverFriendsScreen), findsOneWidget);
    expect(find.text('Find Friends'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Back').first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(HomeKeys.notificationButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home notification opens Request with the shared route', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pump();

    await tester.tap(find.byKey(HomeKeys.notificationButton));
    await tester.pumpAndSettle();

    expect(find.text('Request'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Circles'), findsOneWidget);
  });

  testWidgets('Home greeting keeps emoji fallback fonts under Poppins', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen.demo()));
    await tester.pump();

    final greeting = tester.widget<Text>(find.byKey(HomeKeys.greeting));
    expect(greeting.style?.fontFamilyFallback, isNotNull);
    expect(greeting.style!.fontFamilyFallback, contains('Noto Color Emoji'));
  });
}
