import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/orbit_searchable_header.dart';

void main() {
  testWidgets('search header opens, filters callback, closes and clears', (
    tester,
  ) async {
    final controller = OrbitSearchController();
    addTearDown(controller.dispose);
    final queries = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: OrbitSearchableHeader(
              title: 'Friends',
              placeholder: 'Search friends',
              controller: controller,
              onQueryChanged: queries.add,
              showBack: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Search Friends'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'emma');
    expect(queries.last, 'emma');

    await tester.tap(find.bySemanticsLabel('Close search'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(queries.last, '');
    expect(tester.takeException(), isNull);
  });
}
