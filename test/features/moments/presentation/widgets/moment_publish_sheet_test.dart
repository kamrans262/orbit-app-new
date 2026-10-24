import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/domain/models/moment_publish_models.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/moment_publish_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const circles = <MomentAudienceCircle>[
    MomentAudienceCircle(id: 'a', name: 'Best Friends'),
    MomentAudienceCircle(id: 'b', name: 'Family'),
  ];

  Future<void> showSheet(
    WidgetTester tester, {
    MomentPublisher? publisher,
    OrbitPrivatePhotoSaver? privateSaver,
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMomentPublishingSheet(
                context,
                photoBytes: Uint8List.fromList(const <int>[1, 2, 3]),
                circles: circles,
                publisher: publisher,
                privateSaver: privateSaver,
              ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'review and audience are linked, selection required, no overflow',
    (tester) async {
      await showSheet(tester);
      expect(find.byKey(MomentPublishKeys.review), findsOneWidget);
      expect(find.byKey(MomentPublishKeys.unavailable), findsOneWidget);
      await tester.ensureVisible(find.byKey(MomentPublishKeys.chooseAudience));
      await tester.tap(find.byKey(MomentPublishKeys.chooseAudience));
      await tester.pumpAndSettle();
      expect(find.byKey(MomentPublishKeys.audience), findsOneWidget);
      expect(find.text('Select a circle'), findsOneWidget);
      await tester.tap(find.byKey(MomentPublishKeys.circle('a')));
      await tester.pumpAndSettle();
      expect(find.text('Continue with 1 circle'), findsOneWidget);
      await tester.tap(find.text('Continue with 1 circle'));
      await tester.pumpAndSettle();
      expect(find.text('1 circle selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('publisher failure shows retry; retry requires real receipt', (
    tester,
  ) async {
    var attempts = 0;
    Future<MomentPublishReceipt> publish(
      MomentPublishRequest request,
      void Function(double) progress,
    ) async {
      attempts++;
      expect(request.circleIds, contains('a'));
      progress(0.5);
      if (attempts == 1) throw StateError('Simulated HTTP failure');
      return const MomentPublishReceipt(momentId: 'server-confirmed-001');
    }

    await showSheet(tester, publisher: publish);
    await tester.ensureVisible(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.tap(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentPublishKeys.circle('a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with 1 circle'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Publish Moment'));
    await tester.tap(find.text('Publish Moment'));
    await tester.pumpAndSettle();
    expect(find.text('Publishing interrupted'), findsOneWidget);
    await tester.tap(find.byKey(MomentPublishKeys.retry));
    await tester.pumpAndSettle();
    expect(find.text('Your Moment is live'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview is explicitly labelled and does not call a publisher', (
    tester,
  ) async {
    await showSheet(tester);
    await tester.ensureVisible(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.tap(find.byKey(MomentPublishKeys.chooseAudience));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MomentPublishKeys.circle('a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with 1 circle'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Preview publishing flow'), 80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Preview publishing flow'));
    // The preview action sits below the short 320x568 test window; the
    // approved Orbit sheet is scrollable, not a new popup component.
    await tester.drag(find.byKey(MomentPublishKeys.review),
      const Offset(0, -210));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview publishing flow'));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();
    expect(find.text('Preview completed'), findsOneWidget);
    expect(find.textContaining('Nothing was uploaded or sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('private save uses real M6 callback without fabricated audience', (
    tester,
  ) async {
    var stored = false;
    await showSheet(tester, privateSaver: (bytes, progress) async {
      expect(bytes, isNotEmpty);
      progress(0.9);
      stored = true;
      progress(1);
    });
    expect(find.byKey(MomentPublishKeys.chooseAudience), findsNothing);
    expect(find.text('Save privately'), findsOneWidget);
    await tester.ensureVisible(find.text('Save privately'));
    await tester.tap(find.text('Save privately'));
    await tester.pumpAndSettle();
    expect(stored, true);
    expect(find.text('Photo saved privately'), findsOneWidget);
    expect(find.textContaining('Nothing was shared with a Circle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
