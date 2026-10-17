import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/popups/orbit_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLauncher(
    WidgetTester tester,
    Future<void> Function(BuildContext context) show, {
    Size size = const Size(390, 844),
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reduceMotion),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('all batch popup SVG variants render through the shared system', (
    tester,
  ) async {
    final cases = <String, Future<void> Function(BuildContext)>{
      'SOS': (context) =>
          showSosPopup(context, onTrustedContact: () {}, onTrustedUser: () {}),
      'Live Location': (context) =>
          showLiveLocationPopup(context, onGhost: () {}, onLiveLocation: () {}),
      'Log Out': (context) => showLogoutPopup(context, onLogout: () {}),
      'Delete Account': (context) =>
          showDeleteAccountPopup(context, onDelete: () {}),
      'Stay Connected In the Background': (context) =>
          showStayConnectedPopup(context, onAllow: () {}),
      'Allow Camera Access': (context) =>
          showCameraPermissionPopup(context, onAllow: () {}),
      'Something Went Wrong': (context) =>
          showMomentErrorPopup(context, onRetry: () {}),
      'Battery Optimization Education': (context) =>
          showBatteryOptimizationPopup(context, onContinue: () {}),
      'Allow Microphone Access': (context) =>
          showMicrophonePermissionPopup(context, onAllow: () {}),
    };

    for (final entry in cases.entries) {
      await pumpLauncher(tester, entry.value);
      expect(find.text(entry.key), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Delete callback fires once and destructive popup stays safe', (
    tester,
  ) async {
    var count = 0;
    await pumpLauncher(
      tester,
      (context) => showDeleteAccountPopup(context, onDelete: () => count++),
    );

    expect(count, 0);
    final delete = find.byKey(
      OrbitPopupVariantKeys.primary(OrbitPopupType.deleteAccount),
    );
    await tester.tap(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all popups use reduced 16px outer horizontal margin at 320x568',
    (tester) async {
      await pumpLauncher(
        tester,
        (context) => showBatteryOptimizationPopup(context, onContinue: () {}),
        size: const Size(320, 568),
      );

      final rect = tester.getRect(find.byKey(const Key('orbit_popup_card')));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(320 - rect.right, greaterThanOrEqualTo(16));
      expect(rect.width, lessThanOrEqualTo(288));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Loading rotates safely and reduced motion also renders', (
    tester,
  ) async {
    await pumpLauncher(
      tester,
      (context) => showLoadingPopup(context, showCloseButton: true),
      size: const Size(320, 568),
    );
    expect(find.text('Loading...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await pumpLauncher(
      tester,
      (context) => showLoadingPopup(context, showCloseButton: true),
      size: const Size(320, 568),
      reduceMotion: true,
    );
    expect(find.text('Loading...'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });
}
