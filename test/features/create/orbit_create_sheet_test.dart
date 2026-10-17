import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/create/presentation/screens/orbit_create_sheet.dart';

void main() {
  for (final width in <double>[320, 430]) {
    testWidgets('Create sheet cards and dismiss at $width px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => OrbitCreateSheet.open(context),
                  child: const Text('Open Create'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Create'));
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(find.byKey(OrbitCreateKeys.postMoment), findsOneWidget);
      expect(find.byKey(OrbitCreateKeys.writePost), findsOneWidget);
      expect(find.byKey(OrbitCreateKeys.ping), findsOneWidget);
      expect(find.byKey(OrbitCreateKeys.sos), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(OrbitCreateKeys.close));
      await tester.pumpAndSettle();
      expect(find.byKey(OrbitCreateKeys.sheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
