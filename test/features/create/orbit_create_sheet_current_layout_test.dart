import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_bottom_navigation_bar.dart';
import 'package:orbit_ui/features/create/presentation/screens/orbit_create_sheet.dart';

void main() {
  for (final width in <double>[320, 347, 390, 430]) {
    testWidgets(
      'Create stays above original navigation bar; four-card grid at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => OrbitCreateSheet.open(context),
                    child: const Text('Show Create'),
                  ),
                ),
              ),
              bottomNavigationBar: AppBottomNavigationBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
                onAddPressed: () {},
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show Create'));
        await tester.pumpAndSettle();
        final panel = find.byKey(OrbitCreateKeys.panel);
        expect(panel, findsOneWidget);
        // Current requirement: no dim layer and the original dock remains visible.
        // The panel ends at the top of the 70px navigation dock.
        expect(
          tester.getBottomRight(panel).dy,
          closeTo(568 - AppBottomNavigationBar.referenceHeight, 0.5),
        );
        // The circular + is rendered in front of the panel, not clipped by it.
        final foregroundAdd = find.byKey(OrbitCreateKeys.foregroundAdd);
        expect(foregroundAdd.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(foregroundAdd).dy,
            lessThan(tester.getBottomRight(panel).dy));
        for (final key in <Key>[
          OrbitCreateKeys.postMoment,
          OrbitCreateKeys.writePost,
          OrbitCreateKeys.ping,
          OrbitCreateKeys.sos,
        ]) {
          expect(find.byKey(key), findsOneWidget);
        }
        expect(
          tester.getTopLeft(find.byKey(OrbitCreateKeys.postMoment)).dy,
          closeTo(
            tester.getTopLeft(find.byKey(OrbitCreateKeys.writePost)).dy,
            0.5,
          ),
        );
        expect(
          tester.getSize(
            find.byKey(const Key('orbit_create_icon_Post a Moment')),
          ),
          const Size(48, 48),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(OrbitCreateKeys.close));
        await tester.pumpAndSettle();
        expect(find.byKey(OrbitCreateKeys.panel), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
