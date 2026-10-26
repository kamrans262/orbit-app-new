import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/home/presentation/widgets/home_circle_avatar_tile.dart';
import 'package:orbit_ui/features/more_menu/presentation/widgets/more_menu_tile.dart';
import 'package:orbit_ui/features/home/presentation/widgets/home_circle_summary_tile.dart';

Widget buildHome({
  required VoidCallback onCircle,
  bool showCircles=true,
  double textScale=1.0,
  List<HomeCircleSummaryData>? circles,
}) => MaterialApp(
  builder:(context, child)=>MediaQuery(
    data:MediaQuery.of(context).copyWith(
      textScaler:TextScaler.linear(textScale),
    ),
    child:child!,
  ),
  home:HomeScreen(
    greetingName:'Authorized Member',useLiveDate:true,
    circleSummaries:circles ?? const <HomeCircleSummaryData>[
      HomeCircleSummaryData(id:'c1',name:'Family',role:'member',memberCount:3),
    ],
    showCircleSection:showCircles,
    onCirclePressed:(_)=>onCircle(),
    peopleSectionTitle:'Friends',planUnavailable:true,
    dashboardNotice:'Some Home sections could not be verified. Retry.',
    onDashboardRetry:(){},
    quickActions:const <QuickActionData>[],
    upcomingPlans:const <UpcomingPlanData>[],
    promoBanner:null,
    favoritePeople:const <FavoritePersonData>[
      FavoritePersonData(id:'u2',name:'Actual Friend',
        status:'Friend',imagePath:''),
    ],
    recentMoments:const <MomentData>[],
    onNotificationPressed:(){},
    onQuickActionPressed:(_){},
    onPlanPressed:(_){},
    onPromoPressed:(){},
    onFavoritePersonPressed:(_){},
    onFavoriteToggle:(_){},
    onMomentPressed:(_){},
    onTabSelected:(_){},
    onAddPressed:(){},
  ),
);

void main(){
  testWidgets('Home header precedes retry notice and uses gradient icons',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildHome(onCircle:(){}));
    await tester.pumpAndSettle();
    final header = find.byKey(HomeKeys.greeting);
    final notice = find.text('Some Home sections could not be verified. Retry.');
    expect(header, findsOneWidget);
    expect(notice, findsOneWidget);
    expect(tester.getTopLeft(header).dy, lessThan(tester.getTopLeft(notice).dy));
    final findFriends = tester.widget<AppCircularIconButton>(
      find.byKey(HomeKeys.findFriendsButton),
    );
    final notifications = tester.widget<AppCircularIconButton>(
      find.byKey(HomeKeys.notificationButton),
    );
    expect(findFriends.iconGradient, AppColors.primaryGradient);
    expect(notifications.iconGradient, AppColors.primaryGradient);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M8 uses original Orbit Menu row with Circle image and heart', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    var presses=0;
    await tester.pumpWidget(buildHome(onCircle:()=>presses++));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Family'),160,
      scrollable:find.byType(Scrollable).first);
    expect(find.text('My Circles'),findsOneWidget);
    expect(find.text('Friends'),findsOneWidget);
    expect(find.text('Family'),findsOneWidget);
    expect(find.text('3 members'),findsOneWidget);
    // M5 Circles reuse the existing Orbit Menu card proportions.
    // M4 Friends still use their original circular avatar design.
    expect(find.ancestor(
      of:find.text('Family'), matching:find.byType(MoreMenuTile),
    ),findsOneWidget);
    expect(find.byType(HomeCircleSummaryTile),findsOneWidget);
    expect(find.ancestor(
      of:find.text('Actual Friend'),
      matching:find.byType(HomeCircleAvatarTile),
    ),findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded),findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded),findsNothing);
    final menu=find.byType(MoreMenuTile);
    expect(tester.widget<MoreMenuTile>(menu).leadingWidget,isNotNull);
    expect(tester.widget<MoreMenuTile>(menu).trailingWidget,isNotNull);
    await tester.tap(find.text('Family'));
    expect(presses,1);
    expect(tester.takeException(),isNull);
  });

  for (final scale in <double>[1.0, 1.5, 2.0, 3.0]) {
    testWidgets(
      'M8 Orbit Menu Circles cards have no overflow at ${scale}x text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320,568));
        addTearDown(()=>tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildHome(onCircle:(){},textScale:scale));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(HomeKeys.circlesList),160,
          scrollable:find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Family'),findsOneWidget);
        expect(find.text('3 members'),findsOneWidget);
        final height=tester.getSize(find.byKey(HomeKeys.circlesList)).height;
        expect(height,greaterThanOrEqualTo(MoreMenuTile.referenceHeight));
        expect(tester.takeException(),isNull);
      },
    );
  }

  testWidgets('Home shows at most 2 Orbit Menu Circle rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    var presses=0;
    await tester.pumpWidget(buildHome(onCircle:()=>presses++,circles:const [
      HomeCircleSummaryData(id:'c1',name:'Family',role:'member',memberCount:3),
      HomeCircleSummaryData(id:'c2',name:'Weekend crew',role:'member',memberCount:5),
      HomeCircleSummaryData(id:'c3',name:'Third Circle',role:'member',memberCount:2),
    ]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(HomeKeys.circlesList),160,
      scrollable:find.byType(Scrollable).first);
    expect(find.byType(HomeCircleSummaryTile),findsNWidgets(2));
    expect(find.text('Family'),findsOneWidget);
    expect(find.text('Weekend crew'),findsOneWidget);
    expect(find.text('Third Circle'),findsNothing);
    final cards=tester.getSize(find.byKey(HomeKeys.circlesList));
    expect(cards.height,greaterThanOrEqualTo(2 * MoreMenuTile.referenceHeight + 10));
    await tester.tap(find.text('Weekend crew'));
    expect(presses,1);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Narrow Home stacks two menu rows without horizontal overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(300,568));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildHome(onCircle:(){},circles:const [
      HomeCircleSummaryData(id:'c1',name:'Family',role:'member',memberCount:3),
      HomeCircleSummaryData(id:'c2',name:'Weekend crew',role:'member',memberCount:5),
      HomeCircleSummaryData(id:'c3',name:'Third Circle',role:'member',memberCount:2),
    ]));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(HomeKeys.circlesList),160,
      scrollable:find.byType(Scrollable).first);
    expect(find.byType(HomeCircleSummaryTile),findsNWidgets(2));
    expect(find.text('Third Circle'),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Disabled Plans do not claim an empty deployed plan service', (tester) async {
    await tester.pumpWidget(buildHome(onCircle:(){}));
    await tester.pumpAndSettle();
    expect(find.text('Plans are not available yet.'),findsOneWidget);
    expect(find.text('No upcoming plans yet.'),findsNothing);
  });

  testWidgets('M8 safe error banner and disabled Circle mode work on compact screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320,568));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildHome(
      onCircle:(){},showCircles:false,textScale:2.0,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Some Home sections could not be verified. Retry.'),
      findsOneWidget);
    expect(find.byKey(HomeKeys.circlesList),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
