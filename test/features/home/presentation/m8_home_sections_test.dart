import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/home/presentation/widgets/home_circle_avatar_tile.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/circle_group_card.dart';

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
  testWidgets('M8 uses original My Circles rectangular card and keeps Friends circular', (tester) async {
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
    // Real M5 Circles use the original My Circles rounded rectangle;
    // M4 friends keep the original circular Home avatars.
    expect(find.ancestor(
      of:find.text('Family'), matching:find.byType(CircleGroupCard),
    ),findsOneWidget);
    expect(find.ancestor(
      of:find.text('Actual Friend'),
      matching:find.byType(HomeCircleAvatarTile),
    ),findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded),findsNothing);
    await tester.tap(find.text('Family'));
    expect(presses,1);
    expect(tester.takeException(),isNull);
  });

  for (final scale in <double>[1.0, 1.5, 2.0, 3.0]) {
    testWidgets(
      'M8 rectangular My Circles cards have no overflow at ${scale}x text',
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
        // At 320px the original My Circles grid fits two columns.
        if (scale==1.0) {
          expect(height,137.0);
        } else {
          expect(height,greaterThan(137.0));
        }
        expect(tester.takeException(),isNull);
      },
    );
  }

  testWidgets('Home shows at most 2 original Circle cards', (tester) async {
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
    expect(find.byType(CircleGroupCard),findsNWidgets(2));
    expect(find.text('Family'),findsOneWidget);
    expect(find.text('Weekend crew'),findsOneWidget);
    expect(find.text('Third Circle'),findsNothing);
    final cards=tester.getSize(find.byKey(HomeKeys.circlesList));
    expect(cards.height,137.0);
    await tester.tap(find.text('Weekend crew'));
    expect(presses,1);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Narrow Home keeps maximum 2 cards without horizontal overflow',
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
    expect(find.byType(CircleGroupCard),findsNWidgets(2));
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
