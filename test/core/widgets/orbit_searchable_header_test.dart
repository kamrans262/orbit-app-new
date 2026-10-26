import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/orbit_searchable_header.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';

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

  testWidgets('compact Orbit header matches every right icon to Back',
      (tester) async {
    final controller = OrbitSearchController();
    addTearDown(controller.dispose);
    var requests = 0;

    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: OrbitSearchableHeader(
          compactTitle: true,
          title: 'Friends',
          placeholder: 'Search friends',
          controller: controller,
          onQueryChanged: (_) {},
          trailingActions: <Widget>[
            AppCircularIconButton(
              semanticLabel: 'Friend requests',
              icon: Icons.person_add_alt_outlined,
              size: 30,
              iconSize: 24,
              iconColor: AppColors.primaryEnd,
              iconGradient: AppColors.primaryGradient,
              onPressed: () => requests++,
            ),
          ],
        ),
      ))),
    ));

    final buttons = tester.widgetList<AppCircularIconButton>(
        find.byType(AppCircularIconButton)).toList();
    expect(buttons, hasLength(3));
    for (final button in buttons) {
      expect(button.size, 30);
      expect(button.iconSize, 24);
    }
    expect(buttons.first.iconColor, Colors.black); // Back remains black.
    for (final action in buttons.skip(1)) {
      expect(action.iconGradient, AppColors.primaryGradient);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Friend requests'));
    expect(requests, 1);
    await tester.tap(find.bySemanticsLabel('Search Friends'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    final searchButtons = tester.widgetList<AppCircularIconButton>(
        find.byType(AppCircularIconButton)).toList();
    expect(searchButtons, hasLength(2));
    for (final button in searchButtons) {
      expect(button.size, 30);
      expect(button.iconSize, 24);
    }
    expect(searchButtons.first.iconColor, Colors.black);
    expect(searchButtons.last.iconGradient, AppColors.primaryGradient);
    await tester.tap(find.bySemanticsLabel('Close search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
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
