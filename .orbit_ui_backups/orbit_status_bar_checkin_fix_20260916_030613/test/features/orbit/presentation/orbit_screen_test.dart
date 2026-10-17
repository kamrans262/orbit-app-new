import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/orbit/domain/models/orbit_models.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';
import 'package:orbit_ui/features/orbit/presentation/widgets/orbit_person_strip_item.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget buildDemo() => MaterialApp(home: OrbitScreen.demo());

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
    const Size(600, 960),
  ]) {
    testWidgets(
      'Orbit collapsed state stays responsive at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildDemo());
        await tester.pumpAndSettle();

        expect(find.byKey(OrbitKeys.map), findsOneWidget);
        expect(find.byKey(OrbitKeys.peopleList), findsOneWidget);
        expect(find.byKey(OrbitKeys.checkInButton), findsOneWidget);
        expect(find.byKey(OrbitKeys.bottomNavigation), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('collapsed person names share one baseline', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    final nameRects = <Rect>[
      tester.getRect(find.byKey(OrbitPersonStripItem.nameKey('suzie'))),
      tester.getRect(find.byKey(OrbitPersonStripItem.nameKey('daisy'))),
      tester.getRect(find.byKey(OrbitPersonStripItem.nameKey('sade'))),
      tester.getRect(find.byKey(OrbitPersonStripItem.nameKey('beth'))),
    ];

    final top = nameRects.first.top;
    for (final rect in nameRects.skip(1)) {
      expect(rect.top, closeTo(top, 0.01));
      expect(rect.height, closeTo(nameRects.first.height, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('four demo people distribute across available strip width', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    final peopleList = tester.getRect(find.byKey(OrbitKeys.peopleList));
    final first = tester.getRect(find.byKey(OrbitKeys.person('suzie')));
    final last = tester.getRect(find.byKey(OrbitKeys.person('beth')));

    expect(first.left, closeTo(peopleList.left, 0.5));
    expect(last.right, closeTo(peopleList.right, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a person expands the same sheet and does not navigate', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    expect(find.byKey(OrbitKeys.expandedHeader), findsNothing);
    await tester.tap(find.byKey(OrbitKeys.person('suzie')));
    await tester.pumpAndSettle();

    expect(find.byKey(OrbitKeys.expandedHeader), findsOneWidget);
    expect(find.text('Message Suzie'), findsOneWidget);
    expect(find.byKey(OrbitKeys.giftGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded sheet opens around the reference half-screen region', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(OrbitKeys.person('suzie')));
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(find.byKey(OrbitKeys.sheet));
    expect(sheetRect.height, greaterThan(360));
    expect(sheetRect.height, lessThan(520));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping another map person updates the same expanded panel', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(OrbitKeys.person('suzie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OrbitKeys.marker('daisy')));
    await tester.pumpAndSettle();

    expect(find.text('Message Daisy'), findsOneWidget);
    expect(find.byKey(OrbitKeys.expandedHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long backend names keep strip alignment and do not overflow', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));

    final people = List<OrbitPersonData>.generate(
      24,
      (index) => OrbitPersonData(
        id: 'person-$index',
        name: index == 0
            ? 'A very long backend supplied person name that must never overflow'
            : 'Person $index',
        imagePath: index.isEven ? 'assets/does_not_exist_$index.png' : null,
        markerX: (index % 5) / 5,
        markerY: (index % 7) / 7,
        isNew: index.isEven,
      ),
    );
    final gifts = List<OrbitGiftData>.generate(
      48,
      (index) =>
          OrbitGiftData(id: 'gift-$index', emoji: '🎉', label: 'Gift $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OrbitScreen(
          people: people,
          gifts: gifts,
          onCheckInPressed: () {},
          onPersonSelected: (_) {},
          onCameraPressed: () {},
          onSendPressed: (_, _) {},
          onGiftPressed: (_) {},
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(OrbitKeys.peopleList), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(OrbitKeys.person('person-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(OrbitKeys.giftGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty backend collections stay usable', (tester) async {
    await setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        home: OrbitScreen(
          people: const <OrbitPersonData>[],
          gifts: const <OrbitGiftData>[],
          onCheckInPressed: () {},
          onPersonSelected: (_) {},
          onCameraPressed: () {},
          onSendPressed: (_, _) {},
          onGiftPressed: (_) {},
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No people in this Orbit yet.'), findsOneWidget);
    expect(find.byKey(OrbitKeys.checkInButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
