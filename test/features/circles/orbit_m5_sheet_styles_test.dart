import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/features/circles/domain/models/circle_invite.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/invite_status_badge.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/orbit_circle_sheet.dart';

void main() {
  for (final width in <double>[320, 390, 430]) {
    testWidgets('Orbit Circle sheet spans ${width.toInt()}px screen',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (context) =>
          TextButton(
            onPressed: () => showOrbitCircleSheet<void>(
              context: context,
              title: 'Member actions',
              builder: (sheet) => OrbitCircleSheetAction(
                title: 'Set ADMIN',
                icon: Icons.manage_accounts_outlined,
                onTap: () => Navigator.of(sheet).pop(),
              ),
            ),
            child: const Text('Open actions'),
          ),
        )),
      ));
      await tester.tap(find.text('Open actions'));
      await tester.pumpAndSettle();
      final surface = find.byKey(const Key('orbit_circle_sheet_surface'));
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, moreOrLessEquals(width));
      expect(find.text('Member actions'), findsOneWidget);
      expect(find.text('Set ADMIN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Accepted Circle invitation uses existing primary gradient',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(
        child: InviteStatusBadge(status: CircleInviteStatus.accepted),
      )),
    ));
    final container = tester.widget<Container>(
        find.ancestor(of: find.text('Accepted'), matching: find.byType(Container)).first);
    final decoration = container.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, <Color>[
      AppColors.primaryStart, AppColors.primaryEnd,
    ]);
    expect(tester.widget<Text>(find.text('Accepted')).style!.color,
        Colors.white);
  });
}
