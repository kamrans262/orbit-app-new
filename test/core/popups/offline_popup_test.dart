import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/connectivity/presentation/widgets/offline_popup.dart';

void main() {
  Future<void> pumpPopup(
    WidgetTester tester, {
    required Future<bool> Function() onRetry,
    Size size = const Size(375, 812),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showOrbitOfflinePopup(context, onRetry: onRetry),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offline popup matches the reusable configuration', (
    tester,
  ) async {
    await pumpPopup(tester, onRetry: () async => false);

    expect(find.text('You’re Offline'), findsOneWidget);
    expect(find.text('Check your connection and try again'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.byKey(OrbitOfflinePopupKeys.illustration), findsOneWidget);
    expect(find.byKey(OrbitOfflinePopupKeys.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry stays open when offline and closes when restored', (
    tester,
  ) async {
    var online = false;
    await pumpPopup(tester, onRetry: () async => online);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('You’re Offline'), findsOneWidget);

    online = true;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('You’re Offline'), findsNothing);
  });

  testWidgets('close dismisses only the popup', (tester) async {
    await pumpPopup(tester, onRetry: () async => false);
    await tester.tap(find.byKey(OrbitOfflinePopupKeys.close));
    await tester.pumpAndSettle();

    expect(find.text('You’re Offline'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('popup remains overflow-safe at 320x568', (tester) async {
    await pumpPopup(
      tester,
      onRetry: () async => false,
      size: const Size(320, 568),
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
