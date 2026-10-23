import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/orbit_searchable_header.dart';

void main() {
  testWidgets('search header opens, updates, clears and closes', (
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

  testWidgets('search route override does not open an inline text field',
      (tester) async {
    final controller = OrbitSearchController();
    addTearDown(controller.dispose);
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SafeArea(child: OrbitSearchableHeader(
        title: 'Friends',
        placeholder: 'Search friends',
        controller: controller,
        showBack: false,
        onQueryChanged: (_) {},
        onSearchPressed: () => opens++,
        searchSemanticLabel: 'Find friends',
      ))),
    ));
    await tester.tap(find.bySemanticsLabel('Find friends'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(controller.isSearching, isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
