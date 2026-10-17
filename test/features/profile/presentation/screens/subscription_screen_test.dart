import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/subscription_screen.dart';

void main() {
  testWidgets(
    'Subscription uses Orbit tiers without claiming a live account plan',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: SubscriptionScreen()));

      expect(find.byKey(SubscriptionKeys.title), findsOneWidget);
      expect(find.text('Not connected to your account yet'), findsOneWidget);
      expect(find.byKey(SubscriptionKeys.plan('free')), findsOneWidget);
      expect(find.byKey(SubscriptionKeys.plan('lite')), findsOneWidget);
      // The plan list is lazy: Plus is only built after scrolling into view.
      await tester.ensureVisible(find.byKey(SubscriptionKeys.plan('lite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SubscriptionKeys.plan('lite')).hitTestable());
      await tester.pump();
      expect(find.text('Choose Orbit Lite'), findsOneWidget);

      await tester.tap(find.byKey(SubscriptionKeys.purchaseButton));
      await tester.pump();
      expect(
        find.text('Purchases will be available after billing is connected.'),
        findsOneWidget,
      );
      expect(find.text('Not connected to your account yet'), findsOneWidget);
    },
  );

  testWidgets('A plan callback does not grant a paid entitlement in the UI', (
    tester,
  ) async {
    OrbitSubscriptionTier? requested;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionScreen(
          onPlanRequested: (tier) {
            requested = tier;
          },
        ),
      ),
    );

    // ListView lazily creates Plus. ensureVisible cannot work on a widget
    // that does not yet exist in the element tree.
    await tester.scrollUntilVisible(
      find.byKey(SubscriptionKeys.plan('plus')),
      170,
      scrollable: find.descendant(
        of: find.byKey(SubscriptionKeys.scrollView),
        matching: find.byType(Scrollable),
      ).first,
    );
    final plus = find.byKey(SubscriptionKeys.plan('plus'));
    expect(plus.hitTestable(), findsOneWidget);
    await tester.tap(plus.hitTestable());
    await tester.pump();
    await tester.tap(find.byKey(SubscriptionKeys.purchaseButton));
    await tester.pump();

    expect(requested, OrbitSubscriptionTier.plus);
    expect(find.text('Not connected to your account yet'), findsOneWidget);
  });
}
