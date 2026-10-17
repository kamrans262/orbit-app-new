import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/domain/models/friend_details_models.dart';
import 'package:orbit_ui/features/circles/presentation/screens/friend_details_screen.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/circle_group_segmented_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in phoneSizes) {
    testWidgets(
      'FriendDetails remains overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final members = List<FriendMemberData>.generate(
          20,
          (index) => FriendMemberData(
            id: 'member-$index',
            name: 'Member $index with a backend name that can be quite long',
            status:
                'Dynamic backend status for member $index that must remain safe',
            imagePath: index.isEven ? null : 'assets/Emma.png',
            isFavorite: index % 3 == 0,
          ),
        );
        final groups = List<CircleGroupData>.generate(
          20,
          (index) => CircleGroupData(
            id: 'group-$index',
            name: 'Group $index with a long dynamic title',
            memberCount: index + 1,
            memberAvatars: const <String?>[
              'assets/Emma.png',
              'assets/Mike.png',
              null,
            ],
            isFavorite: index.isEven,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: FriendDetailsScreen(
              circleName: 'Best Friends and People With Long Dynamic Names',
              members: members,
              groups: groups,
              onBack: () {},
              onAddMember: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(CircleGroupSegmentedControlKeys.group));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byKey(FriendDetailsKeys.scrollView),
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
