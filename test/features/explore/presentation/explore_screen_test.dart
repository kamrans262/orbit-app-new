import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/explore/presentation/screens/explore_screen.dart';

void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in sizes) {
    testWidgets('Explore remains overflow-safe at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: ExploreScreen.demo()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Upcoming Meetups'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byKey(ExploreKeys.scroll), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Join and bookmark states toggle locally', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExploreScreen.demo()));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(ExploreKeys.scroll), const Offset(0, -700));
    await tester.pumpAndSettle();

    final join = find.text('Join').first;
    await tester.tap(join);
    await tester.pump();
    expect(find.text('Joined'), findsWidgets);

    final bookmark = find.bySemanticsLabel('Save meetup').first;
    await tester.tap(bookmark);
    await tester.pump();
    expect(find.bySemanticsLabel('Remove bookmark'), findsWidgets);
  });
}
