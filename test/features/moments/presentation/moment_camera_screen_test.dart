import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_bottom_navigation_bar.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moment_camera_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget wrapCamera() {
    return const MaterialApp(home: MomentCameraScreen(enableCamera: false));
  }

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Moment camera controls stay responsive at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(wrapCamera());
        await tester.pumpAndSettle();

        expect(find.byKey(MomentCameraKeys.closeButton), findsOneWidget);
        expect(find.byKey(MomentCameraKeys.filterButton), findsOneWidget);
        expect(find.byKey(MomentCameraKeys.toolsColumn), findsOneWidget);
        expect(find.byKey(MomentCameraKeys.captureButton), findsOneWidget);
        expect(find.byKey(MomentCameraKeys.textButton), findsOneWidget);
        expect(find.byKey(MomentCameraKeys.sendButton), findsOneWidget);
        expect(find.byType(AppBottomNavigationBar), findsNothing);

        final captureFinder = find.byKey(MomentCameraKeys.captureButton);
        final sendFinder = find.byKey(MomentCameraKeys.sendButton);
        final captureCenter = tester.getCenter(captureFinder);
        final captureRect = tester.getRect(captureFinder);
        final sendRect = tester.getRect(sendFinder);
        expect(captureCenter.dx, closeTo(size.width / 2, 0.5));
        expect(sendRect.left, greaterThanOrEqualTo(captureRect.right));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('camera tool buttons use the requested labels', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(wrapCamera());
    await tester.pumpAndSettle();

    expect(find.text('Flash'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Stickers'), findsOneWidget);
    expect(find.text('Send To'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
