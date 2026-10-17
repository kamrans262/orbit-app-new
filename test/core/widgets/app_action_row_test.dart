import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_action_row.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('AppActionRow keeps 68 minimum height and Figma padding', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppActionRow(
            containerKey: Key('row'),
            leadingIcon: Icons.location_on_outlined,
            iconBackgroundColor: Color(0xFFE3E9FD),
            leadingIconColor: Color(0xFF5D7FF4),
            title: 'Live Location',
          ),
        ),
      ),
    );

    final rowRect = tester.getRect(find.byKey(const Key('row')));
    expect(rowRect.height, greaterThanOrEqualTo(68));

    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byKey(const Key('row')),
            matching: find.byType(Padding),
          )
          .first,
    );
    final insets = padding.padding as EdgeInsets;
    expect(insets.left, 16);
    expect(insets.right, 16);
    expect(insets.top, 14);
    expect(insets.bottom, 14);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppActionRow supports optional functional toggle', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    var value = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: AppActionRow(
                containerKey: const Key('row'),
                toggleKey: const Key('toggle'),
                toggleTrackKey: const Key('track'),
                leadingIcon: Icons.location_on_outlined,
                iconBackgroundColor: const Color(0xFFE3E9FD),
                leadingIconColor: const Color(0xFF5D7FF4),
                title: 'Live Location',
                toggleValue: value,
                onToggleChanged: (next) => setState(() => value = next),
              ),
            );
          },
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('row'))).height,
      greaterThanOrEqualTo(68),
    );
    await tester.tap(find.byKey(const Key('toggle')));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppActionRow supports no toggle and a row tap callback', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppActionRow(
            leadingIcon: Icons.link_rounded,
            iconBackgroundColor: const Color(0xFFF2EAFE),
            leadingIconColor: const Color(0xFF7C3AED),
            title: 'Invite by Link',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Invite by Link'), findsOneWidget);
    await tester.tap(find.text('Invite by Link'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
