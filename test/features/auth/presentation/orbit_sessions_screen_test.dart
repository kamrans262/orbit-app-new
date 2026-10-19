import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/core/widgets/app_screen_header.dart';
import 'package:orbit_ui/core/widgets/orbit_gradient_scaffold_messenger.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_sessions_screen.dart';

void main() {
  testWidgets('Sessions reuses the Orbit Settings header, cards and popups',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: OrbitSessionsScreen(
        onLoadSessions: () async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'sample-session',
            'device_name': 'Test Phone',
            'is_current': false,
            'revoked': false,
            'last_used_at': 'Recently',
          },
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AppScreenHeader), findsOneWidget);
    expect(find.byKey(OrbitSessionsKeys.title), findsOneWidget);
    expect(find.byKey(OrbitSessionsKeys.row('sample-session')), findsOneWidget);
    expect(find.text('Test Phone'), findsOneWidget);
    expect(find.byKey(OrbitSessionsKeys.signOutAll), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(ListTile), findsNothing);

    await tester.tap(find.byKey(OrbitSessionsKeys.revoke('sample-session')));
    await tester.pumpAndSettle();
    expect(find.text('Revoke this session?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Test Phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Existing SnackBars get Orbit gradient and white message text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => OrbitGradientScaffoldMessenger(
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            child: const Text('Show feedback'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved successfully')),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show feedback'));
    await tester.pump();
    expect(find.text('Saved successfully'), findsOneWidget);
    final decoration = tester.widget<DecoratedBox>(
      find.byKey(const Key('orbit_gradient_snackbar')),
    ).decoration as BoxDecoration;
    expect(
      (decoration.gradient as LinearGradient).colors,
      <Color>[AppColors.primaryStart, AppColors.primaryEnd],
    );

    final defaultStyle = tester.widget<DefaultTextStyle>(
      find.ancestor(
        of: find.text('Saved successfully'),
        matching: find.byType(DefaultTextStyle),
      ).first,
    ).style;
    expect(defaultStyle.color, AppColors.white);
    expect(tester.takeException(), isNull);
  });
}
