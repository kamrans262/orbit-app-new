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
        expect(find.byKey(OrbitKeys.liveBadge), findsOneWidget);
        expect(find.byKey(OrbitKeys.timeLabel), findsOneWidget);
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
      tester.getRect(find.byKey(OrbitPersonStripItem.nameKey('saqe'))),
      tester.getRect(find.byKey(OrbitPersonStripItem.nameKey('beth'))),
    ];

    final top = nameRects.first.top;
    for (final rect in nameRects.skip(1)) {
      expect(rect.top, closeTo(top, 0.01));
      expect(rect.height, closeTo(nameRects.first.height, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('removed map HUD overlays stay absent', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    expect(find.text('Best Friends'), findsNothing);
    expect(find.text('34%'), findsNothing);
    expect(find.text('Miami'), findsNothing);
    expect(find.text('Beach'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map preserves its aspect ratio with fitWidth', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    final mapFinder = find.byKey(OrbitKeys.map);
    final imageFinder = find.descendant(
      of: mapFinder,
      matching: find.byType(Image),
    );
    final image = tester.widget<Image>(imageFinder.first);

    expect(image.fit, BoxFit.fitWidth);
    expect(image.width, 390);
    expect(tester.takeException(), isNull);
  });
  testWidgets('check in button stays compact and centered', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(find.byKey(OrbitKeys.sheet));
    final buttonRect = tester.getRect(find.byKey(OrbitKeys.checkInButton));

    expect(buttonRect.width, greaterThanOrEqualTo(150));
    expect(buttonRect.width, lessThan(200));
    expect(buttonRect.center.dx, closeTo(sheetRect.center.dx, 1));
    expect(find.text('Check in'), findsOneWidget);
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

  testWidgets('dragging the collapsed sheet upward does not open a person', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    var selections = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: OrbitScreen(
          people: OrbitScreen.demo().people,
          gifts: OrbitScreen.demo().gifts,
          onCheckInPressed: () {},
          onPersonSelected: (_) => selections++,
          onCameraPressed: () {},
          onSendPressed: (_, _) {},
          onGiftPressed: (_) {},
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(OrbitKeys.expandedHeader), findsNothing);
    await tester.drag(find.byKey(OrbitKeys.sheetHandle), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(selections, 0);
    expect(find.byKey(OrbitKeys.expandedHeader), findsNothing);
    expect(find.byKey(OrbitKeys.peopleList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('check in button stays above the fixed bottom navigation', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(buildDemo());
    await tester.pumpAndSettle();

    final buttonRect = tester.getRect(find.byKey(OrbitKeys.checkInButton));
    final navRect = tester.getRect(find.byKey(OrbitKeys.bottomNavigation));

    expect(buttonRect.bottom, lessThanOrEqualTo(navRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long backend names and many gifts stay usable', (tester) async {
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
}
