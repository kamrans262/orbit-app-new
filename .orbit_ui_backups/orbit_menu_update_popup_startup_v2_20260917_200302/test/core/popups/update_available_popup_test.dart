import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/app_update/domain/models/update_popup_data.dart';
import 'package:orbit_ui/features/app_update/presentation/widgets/update_available_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('update popup uses a transparent modal barrier and blocks taps behind it', (
    tester,
  ) async {
    var backgroundTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => backgroundTaps += 1,
                      child: const ColoredBox(color: Color(0xFFF9F9F9)),
                    ),
                  ),
                  Center(
                    child: ElevatedButton(
                      key: const Key('open_update_popup'),
                      onPressed: () => showUpdateAvailablePopup(context),
                      child: const Text('Open'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_update_popup')));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('v2.4.1'), findsOneWidget);
    expect(find.text('v2.5.0'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(backgroundTaps, 0);
    expect(find.text('Update Available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Later dismisses only the popup', (tester) async {
    await _pumpLauncher(tester);

    await tester.tap(find.byKey(const Key('open_update_popup')));
    await tester.pumpAndSettle();
    expect(find.text('Update Available'), findsOneWidget);

    final later = find.byKey(UpdateAvailablePopupKeys.later);
    expect(later.hitTestable(), findsOneWidget);
    await tester.tap(later.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsNothing);
    expect(find.text('Underlying screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Update Now prevents duplicate submissions while action is running', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    final data = UpdatePopupData(
      currentVersion: 'v2.4.1',
      newVersion: 'v2.5.0',
      title: 'Update Available',
      description: 'A new version is ready.',
      changes: const <String>['One improvement'],
      updateAction: () {
        calls += 1;
        return completer.future;
      },
    );

    await _pumpLauncher(tester, data: data);
    await tester.tap(find.byKey(const Key('open_update_popup')));
    await tester.pumpAndSettle();

    final updateButton = find.byKey(UpdateAvailablePopupKeys.updateNow);
    expect(updateButton.hitTestable(), findsOneWidget);
    await tester.tap(updateButton.hitTestable());
    await tester.pump();
    await tester.tap(updateButton.hitTestable());
    await tester.pump();
    expect(calls, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Update Available'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long update content remains scroll-safe on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final data = UpdatePopupData(
      currentVersion: 'v2.4.1-build-very-long-current',
      newVersion: 'v2.5.0-build-very-long-release',
      title: 'A considerably longer update heading for Orbit',
      description:
          'This deliberately long description verifies that the reusable popup can safely wrap and scroll instead of overflowing on compact devices.',
      changes: List<String>.generate(
        9,
        (index) =>
            'Release note ${index + 1} with enough text to wrap safely across multiple lines.',
      ),
    );

    await _pumpLauncher(tester, data: data);
    await tester.tap(find.byKey(const Key('open_update_popup')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit_popup_scroll_view')), findsOneWidget);
    final updateButton = find.byKey(UpdateAvailablePopupKeys.updateNow);
    await tester.ensureVisible(updateButton);
    await tester.pumpAndSettle();
    expect(updateButton.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('force update hides Later', (tester) async {
    const data = UpdatePopupData(
      currentVersion: 'v1',
      newVersion: 'v2',
      title: 'Update Available',
      description: 'Required update.',
      changes: <String>['Security fixes'],
      isForceUpdate: true,
    );

    await _pumpLauncher(tester, data: data);
    await tester.tap(find.byKey(const Key('open_update_popup')));
    await tester.pumpAndSettle();

    expect(find.byKey(UpdateAvailablePopupKeys.later), findsNothing);
    expect(find.text('Update Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  UpdatePopupData data = UpdatePopupData.demo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Column(
              children: <Widget>[
                const Expanded(child: Center(child: Text('Underlying screen'))),
                ElevatedButton(
                  key: const Key('open_update_popup'),
                  onPressed: () => showUpdateAvailablePopup(context, data: data),
                  child: const Text('Open'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
}
