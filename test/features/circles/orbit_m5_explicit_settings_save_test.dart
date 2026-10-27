import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_repository.dart';
import 'package:orbit_ui/features/circles/presentation/screens/circle_setting_screen.dart';
import 'package:orbit_ui/features/circles/presentation/screens/orbit_live_circle_settings_screen.dart';

class _FakeCircleRepo extends OrbitCircleRepository {
  int writes = 0;
  String? lastName;
  @override
  Future<OrbitCircle> update(String id,
      {String? name, String? color, String? icon}) async {
    writes++;
    lastName = name;
    return OrbitCircle(
      id: id,
      name: name ?? 'Friends',
      colorValue: color,
      ownerId: 'owner-1',
      role: 'owner',
      memberCount: 2,
      revision: writes + 1,
      capabilities: const {'edit': true, 'archive': true},
    );
  }
}

void main() {
  testWidgets('Circle edits are draft-only until primary Save Changes tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeCircleRepo();
    const circle = OrbitCircle(
      id: 'circle-1',
      name: 'Friends',
      ownerId: 'owner-1',
      role: 'owner',
      memberCount: 2,
      revision: 1,
      capabilities: {'edit': true, 'archive': true},
    );
    await tester.pumpWidget(MaterialApp(
      home: OrbitLiveCircleSettingsScreen(circle: circle, repository: repo),
    ));
    expect(find.byKey(CircleSettingKeys.saveButton), findsOneWidget);
    expect(find.byKey(CircleSettingKeys.deleteButton), findsOneWidget);
    expect(find.byType(AppPrimaryButton), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Renamed Circle');
    await tester.pump(const Duration(seconds: 2));
    expect(repo.writes, 0);
    final saveButton = find.descendant(
      of: find.byKey(CircleSettingKeys.saveButton),
      matching: find.byType(AppPrimaryButton));
    final save = tester.widget<AppPrimaryButton>(saveButton);
    expect(save.enabled, isTrue);

    await tester.ensureVisible(find.byKey(CircleSettingKeys.saveButton));
    await tester.tap(find.byKey(CircleSettingKeys.saveButton));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(repo.lastName, 'Renamed Circle');
    expect(tester.widget<AppPrimaryButton>(saveButton).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
