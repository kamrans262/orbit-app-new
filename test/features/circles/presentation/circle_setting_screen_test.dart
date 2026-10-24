import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/features/circles/domain/models/circle_settings.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_setting_screen.dart';
import 'package:orbit_ui/core/popups/orbit_popup_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settings = CircleSettings(
    id: 'best-friends',
    name: 'Best Friends',
    memberCount: 5,
    colorValue: 0xFF4D6EF5,
    liveLocationEnabled: true,
    momentSharingEnabled: true,
    pingEnabled: false,
    sosAlertsEnabled: true,
  );

  testWidgets('renders the complete loaded Circle Setting UI', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CircleSettingScreen(settings: settings)),
    );

    expect(find.text('Setting'), findsOneWidget);
    expect(find.text('Best Friends'), findsNWidgets(2));
    expect(find.text('5 members'), findsOneWidget);
    expect(find.text('Circle Name'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Live Location'), findsOneWidget);
    expect(find.text('Moment Sharing'), findsOneWidget);
    expect(find.text('Ping'), findsOneWidget);
    expect(find.text('SOS Alerts'), findsOneWidget);
    expect(find.text('Delete Circle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manage Circle action matches existing Back button', (tester) async {
    var managed = 0;
    await tester.pumpWidget(MaterialApp(
      home: CircleSettingScreen(
        settings: settings,
        onManagePressed: () => managed++,
      ),
    ));
    final back = tester.widget<AppCircularIconButton>(
        find.byKey(CircleSettingKeys.backButton));
    final manage = tester.widget<AppCircularIconButton>(
        find.byWidgetPredicate((widget) =>
            widget is AppCircularIconButton &&
            widget.semanticLabel == 'Manage Circle'));
    expect(back.size, 30);
    expect(manage.size, back.size);
    expect(manage.iconSize, back.iconSize);
    expect(manage.iconColor, back.iconColor);
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is AppCircularIconButton &&
        widget.semanticLabel == 'Manage Circle'));
    expect(managed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggles remain independent and report backend-ready state', (
    tester,
  ) async {
    CircleSettings? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: CircleSettingScreen(
          settings: settings,
          onSettingsChanged: (value) => changed = value,
        ),
      ),
    );

    await tester.tap(find.byKey(CircleSettingKeys.toggle('ping')));
    await tester.pump(const Duration(milliseconds: 180));

    expect(changed, isNotNull);
    expect(changed!.pingEnabled, isTrue);
    expect(changed!.liveLocationEnabled, isTrue);
    expect(changed!.momentSharingEnabled, isTrue);
    expect(changed!.sosAlertsEnabled, isTrue);
  });

  testWidgets('delete requires confirmation before callback', (tester) async {
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CircleSettingScreen(
          settings: settings,
          onDeleteConfirmed: (_) => deleteCount += 1,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(CircleSettingKeys.deleteButton));
    await tester.tap(find.byKey(CircleSettingKeys.deleteButton));
    await tester.pumpAndSettle();

    expect(find.text('Delete Circle?'), findsOneWidget);
    expect(find.byType(OrbitPopupModal), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(deleteCount, 0);

    await tester.tap(find.byKey(CircleSettingKeys.deleteConfirmButton));
    await tester.pumpAndSettle();
    expect(deleteCount, 1);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('is overflow-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: CircleSettingScreen(
            settings: CircleSettings(
              id: 'stress',
              name:
                  'Best Friends With A Very Long Backend Provided Circle Name',
              memberCount: 987654321,
              colorValue: 0xFFA24BEA,
              liveLocationEnabled: true,
              momentSharingEnabled: true,
              pingEnabled: false,
              sosAlertsEnabled: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(CircleSettingKeys.scrollView),
        const Offset(0, -700),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
