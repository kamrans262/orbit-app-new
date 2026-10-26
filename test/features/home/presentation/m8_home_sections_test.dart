import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/screens/home_screen.dart';
import 'package:orbit_ui/features/home/presentation/widgets/home_circle_avatar_tile.dart';

Widget buildHome({
  required VoidCallback onCircle,
  bool showCircles=true,
  double textScale=1.0,
}) => MaterialApp(
  builder:(context, child)=>MediaQuery(
    data:MediaQuery.of(context).copyWith(
      textScaler:TextScaler.linear(textScale),
    ),
    child:child!,
  ),
  home:HomeScreen(
    greetingName:'Authorized Member',useLiveDate:true,
    circleSummaries:const <HomeCircleSummaryData>[
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
  testWidgets('M8 Circle tile is distinct from Friends and deep-link is live', (tester) async {
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
    // M8 must reuse the originally approved Home circular-avatar widget,
    // not a new rectangular or gradient Circle-card design.
    expect(
      find.ancestor(of:find.text('Family'),
        matching:find.byType(HomeCircleAvatarTile)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.groups_outlined),findsNothing);
    await tester.tap(find.text('Family'));
    expect(presses,1);
    expect(tester.takeException(),isNull);
  });

  for (final scale in <double>[1.0, 1.5, 2.0, 3.0]) {
    testWidgets(
      'M8 circular My Circles rail has no RenderFlex overflow at ${scale}x text',
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
        if (scale==1.0) {
          expect(height,122.0); // Matches original Home people avatar rail.
        } else {
          expect(height,greaterThan(122.0));
        }
        expect(tester.takeException(),isNull);
      },
    );
  }

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
