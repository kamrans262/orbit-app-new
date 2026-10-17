import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget wrap(Widget child) => MaterialApp(home: child);

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
    const Size(600, 960),
  ]) {
    testWidgets('Home is overflow-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      await setPhoneSize(tester, size);
      await tester.pumpWidget(wrap(HomeScreen.demo()));
      await tester.pumpAndSettle();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Next Up'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Recent Moments'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent Moments'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home safely renders empty backend collections', (tester) async {
    await setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      wrap(
        HomeScreen(
          greetingName: '',
          quickActions: const <QuickActionData>[],
          upcomingPlans: const <UpcomingPlanData>[],
          promoBanner: null,
          favoritePeople: const <FavoritePersonData>[],
          recentMoments: const <MomentData>[],
          onNotificationPressed: () {},
          onQuickActionPressed: (action) {},
          onPlanPressed: (plan) {},
          onPromoPressed: () {},
          onFavoritePersonPressed: (person) {},
          onFavoriteToggle: (person) {},
          onMomentPressed: (moment) {},
          onTabSelected: (index) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No quick actions available.'), findsOneWidget);
    expect(find.text('No upcoming plans yet.'), findsOneWidget);
    expect(find.text('No favorite people yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home remains stable with large backend data and long text', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));

    final participants = List<ParticipantData>.generate(
      12,
      (index) => ParticipantData(
        id: 'participant_$index',
        name: 'Participant With A Very Long Backend Name $index',
        imagePath: 'assets/missing_participant_$index.png',
      ),
    );
    final plans = List<UpcomingPlanData>.generate(
      30,
      (index) => UpcomingPlanData(
        id: 'plan_$index',
        title:
            'Very long backend plan title that must never overflow card number $index',
        schedule:
            'A very long schedule description returned by the backend · item $index',
        participants: participants,
      ),
    );
    final favorites = List<FavoritePersonData>.generate(
      80,
      (index) => FavoritePersonData(
        id: 'person_$index',
        name: 'A very long favorite person name from backend number $index',
        status:
            'A long status value that should remain safe on compact screens',
        imagePath: 'assets/missing_person_$index.png',
      ),
    );
    final moments = List<MomentData>.generate(
      30,
      (index) => MomentData(
        id: 'moment_$index',
        name: 'Long backend moment owner $index',
        timeLabel: 'A long backend time string $index',
        imagePath: 'assets/missing_moment_$index.jpg',
      ),
    );

    await tester.pumpWidget(
      wrap(
        HomeScreen(
          greetingName:
              'A User With An Extremely Long Name Returned By The Backend',
          quickActions: List<QuickActionData>.generate(
            20,
            (index) => QuickActionData(
              id: 'action_$index',
              title: 'Long Action $index',
              icon: Icons.star_outline,
              iconColor: const Color(0xFF7C3AED),
              iconBackground: const Color(0xFFF2EAFE),
            ),
          ),
          upcomingPlans: plans,
          promoBanner: const PromoBannerData(
            id: 'promo',
            backgroundImagePath: 'assets/missing_banner.png',
            logoImagePath: 'assets/missing_logo.png',
            title: 'A very long promotional title from backend that needs to stay safe',
            subtitle: 'A long promotional subtitle from backend that must never collapse the UI',
          ),
          favoritePeople: favorites,
          recentMoments: moments,
          onNotificationPressed: () {},
          onQuickActionPressed: (action) {},
          onPlanPressed: (plan) {},
          onPromoPressed: () {},
          onFavoritePersonPressed: (person) {},
          onFavoriteToggle: (person) {},
          onMomentPressed: (moment) {},
          onTabSelected: (index) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The people list scrolls horizontally inside Home's vertical sliver view.
    // Move the main view to that list before exercising its lazy final item.
    const listKey = Key('home_circle_horizontal_list');
    final peopleList = find.byKey(listKey);
    await tester.scrollUntilVisible(
      peopleList,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(peopleList, findsOneWidget);
    // ListView.separated exposes its item count via the child delegate;
    // ListView itself has no itemCount getter.
    expect(
      tester.widget<ListView>(peopleList).childrenDelegate.estimatedChildCount,
      159, // 80 people interleaved with 79 separators.
    );
    const lastPersonKey = ValueKey<String>('favorite_person_79');
    await tester.dragUntilVisible(
      find.byKey(lastPersonKey),
      peopleList,
      const Offset(-280, 0),
      maxIteration: 45,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(lastPersonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home loading state is stable', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      wrap(
        HomeScreen(
          greetingName: 'Emma',
          quickActions: const <QuickActionData>[],
          upcomingPlans: const <UpcomingPlanData>[],
          promoBanner: null,
          favoritePeople: const <FavoritePersonData>[],
          recentMoments: const <MomentData>[],
          onNotificationPressed: () {},
          onQuickActionPressed: (action) {},
          onPlanPressed: (plan) {},
          onPromoPressed: () {},
          onFavoritePersonPressed: (person) {},
          onFavoriteToggle: (person) {},
          onMomentPressed: (moment) {},
          onTabSelected: (index) {},
          onAddPressed: () {},
          isLoading: true,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
