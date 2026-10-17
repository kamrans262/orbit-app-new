import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_action_row.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/circle_setting_toggle.dart';
import 'package:orbit_ui/features/profile/domain/models/notification_settings.dart';
import 'package:orbit_ui/features/profile/presentation/screens/notification_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Notification renders Figma rows and independent demo states', (
    tester,
  ) async {
    await _pumpNotification(tester);

    expect(find.text('Notification'), findsOneWidget);
    expect(find.byType(AppActionRow), findsNWidgets(7));

    for (final label in <String>[
      'Push Notification',
      'Ping notifications',
      'Moments notifications',
      'Circle updates',
      'SOS alerts',
      'Sound',
      'Vibration',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(_toggle(tester, 'push').value, isTrue);
    expect(_toggle(tester, 'ping').value, isTrue);
    expect(_toggle(tester, 'moments').value, isTrue);
    expect(_toggle(tester, 'circle_updates').value, isTrue);
    expect(_toggle(tester, 'sos').value, isTrue);
    expect(_toggle(tester, 'sound').value, isFalse);
    expect(_toggle(tester, 'vibration').value, isTrue);

    // The row key identifies AppActionRow's decorated container, not the
    // AppActionRow widget itself. Find the owning row before reading its props.
    final firstRow = tester.widget<AppActionRow>(
      find.ancestor(
        of: find.byKey(NotificationKeys.row('push')),
        matching: find.byType(AppActionRow),
      ),
    );
    expect(firstRow.showLeading, isFalse);
    expect(AppActionRow.referenceHeight, 68);
    expect(AppActionRow.radius, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Changing one notification option preserves the others', (
    tester,
  ) async {
    final changes = <NotificationSettings>[];
    await _pumpNotification(tester, onSettingsChanged: changes.add);

    await tester.tap(find.byKey(NotificationKeys.row('sound')));
    await tester.pump();

    expect(_toggle(tester, 'sound').value, isTrue);
    expect(_toggle(tester, 'push').value, isTrue);
    expect(_toggle(tester, 'ping').value, isTrue);
    expect(_toggle(tester, 'moments').value, isTrue);
    expect(_toggle(tester, 'circle_updates').value, isTrue);
    expect(_toggle(tester, 'sos').value, isTrue);
    expect(_toggle(tester, 'vibration').value, isTrue);
    expect(changes, hasLength(1));
    expect(changes.single.soundEnabled, isTrue);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Notification remains scroll-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await _pumpNotification(tester);
        expect(find.byKey(NotificationKeys.scrollView), findsOneWidget);

        await tester.drag(
          find.byKey(NotificationKeys.scrollView),
          const Offset(0, -280),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vibration'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

CircleSettingToggle _toggle(WidgetTester tester, String id) {
  return tester.widget<CircleSettingToggle>(
    find.byKey(NotificationKeys.toggle(id)),
  );
}

Future<void> _pumpNotification(
  WidgetTester tester, {
  ValueChanged<NotificationSettings>? onSettingsChanged,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(home: NotificationScreen(onSettingsChanged: onSettingsChanged)),
  );
  await tester.pump();
}
