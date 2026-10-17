import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/report_user_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/report_user_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Report User matches the reference structure and demo selection',
    (tester) async {
      await _pump(tester, ReportUserScreen.demo());

      expect(find.text('Report User'), findsOneWidget);
      expect(find.text('Why are you reporting Mike Smith?'), findsOneWidget);
      expect(find.text('Inappropriate Content'), findsOneWidget);
      expect(find.text('Harassment'), findsOneWidget);
      expect(find.text('Spam'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
      expect(find.byKey(ReportUserKeys.card), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reason selection is exclusive and submits backend-ready request',
    (tester) async {
      ReportRequest? submitted;
      var submissionCount = 0;

      await _pump(
        tester,
        ReportUserScreen(
          args: const ReportUserArgs(
            userId: 'mike-42',
            displayName: 'Mike Smith',
          ),
          onSubmit: (request) async {
            submissionCount += 1;
            submitted = request;
          },
        ),
      );

      final submitButton = find.byKey(ReportUserKeys.submitButton);
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      expect(submitButton.hitTestable(), findsOneWidget);
      await tester.tap(submitButton.hitTestable());
      await tester.pump();
      expect(find.text('Select a reason before submitting.'), findsOneWidget);
      expect(submissionCount, 0);
      // Dismiss the validation SnackBar before expecting the later success
      // SnackBar. Otherwise success queues behind the still-visible error.
      ScaffoldMessenger.of(tester.element(submitButton)).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      final harassment = find.byKey(
        ReportUserKeys.reasonRow(ReportReason.harassment),
      );
      await tester.ensureVisible(harassment);
      await tester.pumpAndSettle();
      expect(harassment.hitTestable(), findsOneWidget);
      await tester.tap(harassment.hitTestable());
      await tester.pump();

      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      expect(submitButton.hitTestable(), findsOneWidget);
      await tester.tap(submitButton.hitTestable());
      await tester.pumpAndSettle();

      expect(submissionCount, 1);
      expect(submitted, isNotNull);
      expect(submitted!.reportedUserId, 'mike-42');
      expect(submitted!.reason, ReportReason.harassment);
      expect(find.text('Report submitted. Thank you.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dynamic long reported-user names wrap without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      const ReportUserScreen(
        args: ReportUserArgs(
          userId: 'long-user',
          displayName: 'Alexandra Catherine Montgomery-Wellington the Third',
        ),
        initialReason: ReportReason.other,
      ),
      size: const Size(320, 568),
    );

    expect(find.byKey(ReportUserKeys.scrollView), findsOneWidget);
    expect(
      find.textContaining('Why are you reporting Alexandra'),
      findsOneWidget,
    );

    final submitButton = find.byKey(ReportUserKeys.submitButton);
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    expect(submitButton.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Report User remains overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        await _pump(tester, ReportUserScreen.demo(), size: size);

        expect(find.byKey(ReportUserKeys.scrollView), findsOneWidget);
        final submitButton = find.byKey(ReportUserKeys.submitButton);
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();
        expect(submitButton.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}
