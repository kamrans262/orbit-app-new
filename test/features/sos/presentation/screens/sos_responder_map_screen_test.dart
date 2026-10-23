import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/sos/presentation/screens/sos_alert_screen.dart';
import 'package:orbit_ui/features/sos/presentation/screens/sos_responder_map_screen.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';

void main() {
  testWidgets('SOS demo links to preview, never claiming an alert was sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: SosAlertScreen.demo()));
    final preview = find.byKey(const Key('sos-preview-responder-map'));
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.byKey(SosResponderMapKeys.screen), findsOneWidget);
    expect(find.byKey(SosResponderMapKeys.previewBanner), findsOneWidget);
    expect(find.byType(AppCircularIconButton), findsOneWidget);
    expect(find.text('Preview only — no SOS was sent'), findsOneWidget);
    // The responder section is below the first viewport in the lazy ListView.
    await tester.scrollUntilVisible(
      find.byKey(SosResponderMapKeys.emptyResponders),
      180,
      scrollable: find.descendant(
        of: find.byKey(SosResponderMapKeys.screen),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.byKey(SosResponderMapKeys.emptyResponders), findsOneWidget);
    expect(find.byKey(SosResponderMapKeys.resolveButton), findsNothing);
    expect(find.byKey(SosResponderMapKeys.engageButton), findsNothing);
  });

  testWidgets('Confirmed session renders only supplied responder information', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: SosResponderMapScreen(
          session: SosResponderSession(
            id: 'confirmed-event',
            serverConfirmed: true,
            originatorName: 'Alex',
            circleName: 'Family',
            status: 'Active',
            deliveryLabel: 'Notification acknowledged',
            responders: <SosResponderPerson>[
              SosResponderPerson(
                id: 'r1',
                name: 'Sam',
                status: 'Responding',
                etaLabel: '8 min',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(SosResponderMapKeys.liveBanner), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
    expect(find.text('Live map not connected'), findsOneWidget);
  });

  testWidgets('320x568 preview is scroll-safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SosResponderMapScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(SosResponderMapKeys.previewBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
