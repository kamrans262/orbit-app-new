import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/no_moments_popup.dart';

void main() {
  testWidgets('No Moments popup closes without changing the underlying route', (
    tester,
  ) async {
    var createCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showNoMomentsPopup(
                  context,
                  onCreateMoment: () => createCount++,
                ),
                child: const Text('Show popup'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show popup'));
    await tester.pumpAndSettle();

    expect(find.text('No moments Yet'), findsOneWidget);
    expect(find.text('Share your first moment with your circle'), findsOneWidget);
    expect(find.byKey(NoMomentsPopupKeys.close), findsOneWidget);

    await tester.tap(find.byKey(NoMomentsPopupKeys.close));
    await tester.pumpAndSettle();

    expect(find.text('No moments Yet'), findsNothing);
    expect(find.text('Show popup'), findsOneWidget);
    expect(createCount, 0);
  });

  testWidgets('Create Moment dismisses popup then invokes existing flow callback', (
    tester,
  ) async {
    var createCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showNoMomentsPopup(
                  context,
                  onCreateMoment: () => createCount++,
                ),
                child: const Text('Show popup'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show popup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(NoMomentsPopupKeys.createMoment));
    await tester.pumpAndSettle();

    expect(find.text('No moments Yet'), findsNothing);
    expect(createCount, 1);
  });

  testWidgets('popup remains overflow-safe on 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showNoMomentsPopup(
                context,
                onCreateMoment: () {},
              ),
              child: const Text('Show popup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show popup'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Create Moment'), findsOneWidget);
  });
}
