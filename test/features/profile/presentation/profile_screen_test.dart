import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Profile demo renders backend-driven header and active Profile tab',
    (tester) async {
      await _pumpProfile(tester, ProfileScreen.demo());

      expect(find.text('Emma ⭐'), findsOneWidget);
      expect(find.text('Good vibes only'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      // The current Profile opens on Overview; the masonry gallery is in
      // Moments. Check both destinations without changing the default tab.
      expect(find.byKey(ProfileKeys.overviewTab), findsOneWidget);
      expect(find.byKey(ProfileKeys.gallery), findsNothing);
      expect(find.byKey(ProfileKeys.bottomNavigation), findsOneWidget);
      await tester.tap(find.byKey(ProfileKeys.momentsTab));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileKeys.gallery), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile supports dynamic stats and arbitrary masonry content', (
    tester,
  ) async {
    final moments = List<ProfileMomentData>.generate(
      5,
      (index) =>
          ProfileMomentData(id: 'moment-$index', likeCount: index * 1000),
    );

    await _pumpProfile(
      tester,
      ProfileScreen(
        profile: ProfileData(
          id: 'dynamic',
          name: 'A very long backend profile name that must remain safe',
          bio: 'A longer backend biography that is allowed to wrap naturally without forcing a fixed-height container.',
          circleCount: 3,
          friendCount: 999,
          momentCount: moments.length,
          moments: moments,
        ),
        onTabSelected: (_) {},
        onAddPressed: () {},
        onRetry: () {},
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byKey(ProfileKeys.moment('moment-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Moment tile opens detail flow and reports the selected model', (
    tester,
  ) async {
    ProfileMomentData? selected;
    const moment = ProfileMomentData(id: 'tap-me', likeCount: 7);

    await _pumpProfile(
      tester,
      ProfileScreen(
        profile: const ProfileData(
          id: 'emma',
          name: 'Emma',
          bio: 'Bio',
          circleCount: 1,
          friendCount: 2,
          momentCount: 1,
          moments: <ProfileMomentData>[moment],
        ),
        onTabSelected: (_) {},
        onAddPressed: () {},
        onRetry: () {},
        onMomentPressed: (value) => selected = value,
        momentDetailBuilder: (context, value) =>
            const Scaffold(body: Center(child: Text('Moment detail target'))),
      ),
    );

    await tester.tap(find.byKey(ProfileKeys.momentsTab));
    await tester.pumpAndSettle();
    final tile = find.byKey(ProfileKeys.moment('tap-me'));
    // A masonry tile can be built below the viewport. Scrolling to it and
    // checking hit-testability avoids a false tap at the default 800x600 size.
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tile.hitTestable(), findsOneWidget);
    await tester.tap(tile.hitTestable());
    await tester.pumpAndSettle();

    expect(selected?.id, 'tap-me');
    expect(find.text('Moment detail target'), findsOneWidget);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Profile remains overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await _pumpProfile(tester, ProfileScreen.demo());
        await tester.drag(
          find.byKey(ProfileKeys.scrollView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Profile loading empty and error states are supported', (
    tester,
  ) async {
    const data = ProfileData(
      id: 'state',
      name: 'Emma',
      bio: 'Bio',
      circleCount: 0,
      friendCount: 0,
      momentCount: 0,
      moments: <ProfileMomentData>[],
    );

    for (final state in <ProfileViewState>[
      ProfileViewState.loading,
      ProfileViewState.empty,
      ProfileViewState.error,
    ]) {
      await _pumpProfile(
        tester,
        ProfileScreen(
          profile: data,
          viewState: state,
          onTabSelected: (_) {},
          onAddPressed: () {},
          onRetry: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpProfile(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}
