import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/home/presentation/widgets/promo_banner_card.dart';
import 'package:orbit_ui/features/circles/presentation/screens/friend_details_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets(
    'four quick actions fill the available Home content width evenly',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      await tester.pumpWidget(wrap(HomeScreen.demo()));
      await tester.pumpAndSettle();

      final cards = <Finder>[
        find.byKey(const ValueKey<String>('quick_action_ping')),
        find.byKey(const ValueKey<String>('quick_action_sos')),
        find.byKey(const ValueKey<String>('quick_action_explore')),
        find.byKey(const ValueKey<String>('quick_action_moment')),
      ];
      final rects = cards.map(tester.getRect).toList();

      expect(rects.first.left, closeTo(15, 0.01));
      expect(rects.last.right, closeTo(375, 0.01));
      for (var index = 1; index < rects.length; index++) {
        expect(rects[index].left - rects[index - 1].right, closeTo(10, 0.01));
        expect(rects[index].width, closeTo(rects.first.width, 0.01));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick actions remain horizontally scrollable with backend growth',
    (tester) async {
      await setPhoneSize(tester, const Size(320, 568));
      final actions = List<QuickActionData>.generate(
        12,
        (index) => QuickActionData(
          id: 'dynamic_$index',
          title: 'Backend Action $index',
          icon: Icons.star_outline_rounded,
          iconColor: const Color(0xFF7C3AED),
          iconBackground: const Color(0xFFF2EAFE),
        ),
      );
      final demo = HomeScreen.demo();
      await tester.pumpWidget(
        wrap(
          HomeScreen(
            greetingName: 'Emma',
            quickActions: actions,
            upcomingPlans: demo.upcomingPlans,
            promoBanner: demo.promoBanner,
            favoritePeople: demo.favoritePeople,
            recentMoments: demo.recentMoments,
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

      expect(find.text('Backend Action 0'), findsOneWidget);
      await tester.drag(
        find.byKey(HomeKeys.quickActionsList),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('promo logo to title gap is 10px and title is 16 semibold', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    const data = PromoBannerData(
      id: 'promo',
      backgroundImagePath: 'assets/banner.png',
      logoImagePath: 'assets/bannerlogo.png',
      title: 'Get there together',
      subtitle: 'Ride with friends',
    );
    await tester.pumpWidget(wrap(PromoBannerCard(data: data, onTap: () {})));
    await tester.pumpAndSettle();

    final logoRect = tester.getRect(find.byKey(PromoBannerKeys.logo));
    final titleRect = tester.getRect(find.byKey(PromoBannerKeys.title));
    final title = tester.widget<Text>(find.byKey(PromoBannerKeys.title));

    expect(titleRect.top - logoRect.bottom, closeTo(10, 0.01));
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home circle avatar opens friend details and reports selected friend', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    FavoritePersonData? selected;
    final demo = HomeScreen.demo();
    await tester.pumpWidget(
      wrap(
        HomeScreen(
          greetingName: demo.greetingName,
          quickActions: demo.quickActions,
          upcomingPlans: demo.upcomingPlans,
          promoBanner: demo.promoBanner,
          favoritePeople: const <FavoritePersonData>[
            FavoritePersonData(
              id: 'emma',
              name: 'Emma',
              status: 'Active now',
              imagePath: 'assets/Emma.png',
            ),
          ],
          recentMoments: demo.recentMoments,
          onNotificationPressed: () {},
          onQuickActionPressed: (action) {},
          onPlanPressed: (plan) {},
          onPromoPressed: () {},
          onFavoritePersonPressed: (person) => selected = person,
          onFavoriteToggle: (person) {},
          onMomentPressed: (moment) {},
          onTabSelected: (index) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    const avatarKey = ValueKey<String>('favorite_emma');
    final avatar = find.byKey(avatarKey);
    await tester.scrollUntilVisible(
      avatar,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(avatar);
    await tester.pumpAndSettle();
    expect(avatar, findsOneWidget);
    await tester.tap(avatar);
    await tester.pumpAndSettle();
    expect(selected?.id, 'emma');
    expect(find.byType(FriendDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
