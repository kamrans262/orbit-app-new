import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/help_center/domain/models/help_center_item.dart';
import 'package:orbit_ui/features/help_center/presentation/screens/help_center_screen.dart';
import 'package:orbit_ui/features/help_center/presentation/screens/help_topic_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 866),
    Widget screen = const HelpCenterScreen(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: screen));
    // The loading state's progress indicator animates indefinitely; it must
    // be asserted after a frame rather than waiting for all frames to settle.
    if (screen is HelpCenterScreen &&
        screen.viewState == HelpCenterViewState.loading) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('matches required Help Center content and dynamic list', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Help Center'), findsOneWidget);
    expect(find.text('Search by name or Phone'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Privacy help'), findsOneWidget);
    expect(find.text('Safety help'), findsOneWidget);
    expect(find.text('FAQ’s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search is case-insensitive and whitespace-safe', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(HelpCenterKeys.searchInput),
      '   PRIVACY   ',
    );
    await tester.pump();

    expect(find.text('Privacy help'), findsOneWidget);
    expect(find.text('Contact support'), findsNothing);
    expect(find.text('Safety help'), findsNothing);
    expect(find.text('FAQ’s'), findsNothing);

    await tester.enterText(find.byKey(HelpCenterKeys.searchInput), 'unknown');
    await tester.pump();
    expect(find.text('No help topics found'), findsOneWidget);
  });

  testWidgets('help row opens a real destination screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactSupportScreen), findsOneWidget);
  });

  testWidgets('long backend title remains overflow-safe on compact phone', (
    tester,
  ) async {
    const longItem = HelpCenterItem(
      id: 'long_topic',
      title: 'A very long localized backend help topic title that must remain safe',
      keywords: <String>['long'],
      destination: HelpCenterDestination.faq,
    );

    await pumpScreen(
      tester,
      size: const Size(320, 568),
      screen: const HelpCenterScreen(items: <HelpCenterItem>[longItem]),
    );

    expect(find.byKey(HelpCenterKeys.item('long_topic')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports loading and error states', (tester) async {
    await pumpScreen(
      tester,
      screen: const HelpCenterScreen(viewState: HelpCenterViewState.loading),
    );
    expect(find.byKey(HelpCenterKeys.loadingState), findsOneWidget);

    await pumpScreen(
      tester,
      screen: const HelpCenterScreen(
        viewState: HelpCenterViewState.error,
        errorMessage: 'Could not load topics',
      ),
    );
    expect(find.byKey(HelpCenterKeys.errorState), findsOneWidget);
    expect(find.text('Could not load topics'), findsOneWidget);
  });
}
