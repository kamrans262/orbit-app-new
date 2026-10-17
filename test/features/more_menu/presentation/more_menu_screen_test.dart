import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/more_menu/presentation/screens/more_menu_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders all eight More Menu actions from the reusable list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MoreMenuScreen()));

    expect(find.text('Orbit Menu'), findsOneWidget);
    expect(find.text("What's New"), findsOneWidget);
    expect(find.text('Rate Orbit'), findsOneWidget);
    expect(find.text('Share Orbit'), findsOneWidget);
    expect(find.text('Help Center'), findsOneWidget);
    expect(find.text('Terms of services'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu tiles keep the 10px Figma gap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: MoreMenuScreen()));

    final first = tester.getRect(find.byKey(MoreMenuKeys.tile('whats_new')));
    final second = tester.getRect(find.byKey(MoreMenuKeys.tile('rate_orbit')));

    expect(second.top - first.bottom, moreOrLessEquals(10, epsilon: 0.01));
    expect(first.height, moreOrLessEquals(67, epsilon: 0.01));
  });

  testWidgets("What's New opens the reusable update popup by default", (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MoreMenuScreen()));

    await tester.tap(find.byKey(MoreMenuKeys.tile('whats_new')));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);
  });

  testWidgets('Delete Account never runs before confirmation', (tester) async {
    var deleteCount = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MoreMenuScreen(onDeleteAccountConfirmed: () => deleteCount += 1),
      ),
    );

    final target = find.byKey(MoreMenuKeys.tile('delete_account'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_popup_deleteAccount')), findsOneWidget);
    expect(deleteCount, 0);

    await tester.tap(find.byKey(const Key('orbit_popup_primary_deleteAccount')));
    await tester.pumpAndSettle();
    expect(deleteCount, 1);
  });

  testWidgets('Log Out uses confirmation before its callback', (tester) async {
    var logoutCount = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MoreMenuScreen(onLogoutConfirmed: () => logoutCount += 1),
      ),
    );

    final target = find.byKey(MoreMenuKeys.tile('logout'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_popup_logout')), findsOneWidget);
    expect(logoutCount, 0);

    await tester.tap(find.byKey(const Key('orbit_popup_primary_logout')));
    await tester.pumpAndSettle();
    expect(logoutCount, 1);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'is scroll-safe without RenderFlex overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: MoreMenuScreen(
              labels: MoreMenuLabels(
                termsOfServices: 'Terms of services from a much longer localized backend label',
                deleteAccount:
                    'Delete Account and Permanently Remove My Orbit Profile',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // SliverList children below the viewport are not built until scrolled.
        // Assert the actual final row after bringing it into the viewport.
        await tester.scrollUntilVisible(
          find.byKey(MoreMenuKeys.tile('logout')),
          180,
          scrollable: find.descendant(
            of: find.byKey(MoreMenuKeys.scrollView),
            matching: find.byType(Scrollable),
          ).first,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(MoreMenuKeys.tile('logout')), findsOneWidget);
        expect(find.text('Log Out'), findsOneWidget);
      },
    );
  }
}
