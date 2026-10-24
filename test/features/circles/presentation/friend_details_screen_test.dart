import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/features/circles/domain/models/friend_details_models.dart';
import 'package:orbit_ui/features/circles/presentation/screens/friend_details_screen.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/circle_group_segmented_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<FriendMemberData>? members,
    List<CircleGroupData>? groups,
    FriendDetailsViewState state = FriendDetailsViewState.loaded,
    String circleName = 'Best Friends',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FriendDetailsScreen(
          circleName: circleName,
          members: members ?? demoMembers(),
          groups: groups ?? demoGroups(),
          onBack: () {},
          onAddMember: () {},
          viewState: state,
        ),
      ),
    );
    // An indeterminate loading spinner intentionally never settles.
    // Pump one frame in the loading fixture; settle only finite UI states.
    if (state == FriendDetailsViewState.loading) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('renders header summary and derives member count from data', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Friend Details'), findsOneWidget);
    expect(find.text('Best Friends'), findsOneWidget);
    expect(find.text('5 members'), findsOneWidget);
    expect(find.byKey(FriendDetailsKeys.backButton), findsOneWidget);
    expect(find.byKey(FriendDetailsKeys.addMemberButton), findsOneWidget);
    final back = tester.widget<AppCircularIconButton>(
        find.byKey(FriendDetailsKeys.backButton));
    final addMember = tester.widget<AppCircularIconButton>(
        find.byKey(FriendDetailsKeys.addMemberButton));
    expect(back.size, 30);
    expect(addMember.size, back.size);
    expect(addMember.iconSize, back.iconSize);
    expect(addMember.iconColor, back.iconColor);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('circle tab reuses member rows and favorite toggles locally', (
    tester,
  ) async {
    await pumpScreen(tester);

    final emma = find.byKey(FriendDetailsKeys.member('emma'));
    expect(emma, findsOneWidget);
    expect(
      find.descendant(of: emma, matching: find.byIcon(Icons.favorite_rounded)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: emma, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: emma,
        matching: find.byIcon(Icons.favorite_border_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switches to group grid on the same screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(CircleGroupSegmentedControlKeys.group));
    await tester.pumpAndSettle();

    expect(find.text('Friend Details'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(FriendDetailsKeys.group('basketball')), findsOneWidget);
    expect(find.text('Basketball squad'), findsOneWidget);
    expect(find.text('6 members'), findsOneWidget);
  });

  testWidgets('supports loading empty and error states', (tester) async {
    await pumpScreen(tester, state: FriendDetailsViewState.loading);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpScreen(tester, members: const <FriendMemberData>[]);
    expect(find.text('No members in this circle yet.'), findsOneWidget);

    await pumpScreen(tester, state: FriendDetailsViewState.error);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('long backend text and missing avatars do not overflow', (
    tester,
  ) async {
    final members = <FriendMemberData>[
      FriendMemberData(
        id: 'long',
        name: 'A very long backend-provided friend name that must never overflow the row',
        status: 'A very long live status that can change at any time and still needs a safe responsive layout',
        imagePath: null,
      ),
    ];
    final groups = <CircleGroupData>[
      const CircleGroupData(
        id: 'long-group',
        name: 'A very long group title coming from the backend that should be safely truncated',
        memberCount: 28,
        memberAvatars: <String?>[null, '', 'assets/does_not_exist.png'],
      ),
    ];

    await pumpScreen(
      tester,
      size: const Size(320, 568),
      members: members,
      groups: groups,
      circleName: 'A very long circle name that must stay centered and safe',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(CircleGroupSegmentedControlKeys.group));
    await tester.pumpAndSettle();
    expect(find.textContaining('+'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

List<FriendMemberData> demoMembers() {
  return <FriendMemberData>[
    const FriendMemberData(
      id: 'emma',
      name: 'Emma',
      status: 'Active now',
      imagePath: 'assets/Emma.png',
      isFavorite: true,
    ),
    const FriendMemberData(
      id: 'mike',
      name: 'Mike',
      status: 'Active 5m ago',
      imagePath: 'assets/Mike.png',
    ),
    const FriendMemberData(
      id: 'sophia',
      name: 'Sophia',
      status: 'Active 12m ago',
      imagePath: 'assets/Sophia.png',
    ),
    const FriendMemberData(
      id: 'finn',
      name: 'Finn',
      status: 'At the beach',
      imagePath: 'assets/Emma.png',
    ),
    const FriendMemberData(
      id: 'suzie',
      name: 'Suzie',
      status: 'Active 24m ago',
      imagePath: 'assets/Sophia.png',
    ),
  ];
}

List<CircleGroupData> demoGroups() {
  return <CircleGroupData>[
    const CircleGroupData(
      id: 'basketball',
      name: 'Basketball squad',
      memberCount: 6,
      memberAvatars: <String?>[
        'assets/Emma.png',
        'assets/Mike.png',
        'assets/Sophia.png',
      ],
    ),
    const CircleGroupData(
      id: 'weekend',
      name: 'Weekend crew',
      memberCount: 25,
      memberAvatars: <String?>[
        'assets/Mike.png',
        'assets/Emma.png',
        'assets/Sophia.png',
      ],
    ),
  ];
}
