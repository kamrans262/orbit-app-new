import 'dart:async';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_account_deletion_status_screen.dart';

import 'package:flutter/material.dart';
import 'package:orbit_ui/features/profile/presentation/screens/privacy_setting_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/notification_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/orbit_preferences_screens.dart';
import 'package:orbit_ui/features/circles/presentation/widgets/circle_setting_toggle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/orbit_my_profile_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:orbit_ui/features/profile/data/orbit_profile_settings_repository.dart';
import 'package:orbit_ui/features/profile/domain/models/privacy_settings.dart';
import 'package:orbit_ui/features/profile/domain/models/notification_settings.dart';

class _FakeProfileRepository extends OrbitProfileSettingsRepository {
  Map<String, dynamic> record = <String, dynamic>{
    'id': '2d184c7a-4f2a-40f6-8c48-a1fab1213456',
    'display_name': 'Real User',
    'username': 'real.user',
    'bio': '',
  };

  @override
  Future<Map<String, dynamic>> loadProfile() async => Map<String, dynamic>.from(record);

  @override
  Future<void> saveProfile(String name, String username, {String? bio}) async {
    record = <String, dynamic>{...record, 'display_name': name,
      'username': username, if (bio != null) 'bio': bio};
  }
}

class _FakeDeletionClient extends OrbitIdentityClient {
  bool cancelled = false;

  @override
  Future<Map<String, dynamic>> deletionStatus() async => <String, dynamic>{
    'status': 'pending',
    'request_id': 'fixture-id',
    'can_cancel': true,
    'eligible_for_erasure_at': '2026-11-20T00:00:00+00:00',
  };

  @override
  Future<void> cancelDeletion() async { cancelled = true; }
}

void main() {
  final repo = OrbitProfileSettingsRepository();

  test('Authenticated profile mapping never displays fabricated users or counts', () {
    final profile = repo.fromProfile(<String, dynamic>{
      'id': '2d184c7a-4f2a-40f6-8c48-a1fab1213456',
      'display_name': 'Real User',
      'username': 'real.user',
      'bio': 'Private bio',
    });
    expect(profile.name, 'Real User');
    expect(profile.bio, 'Private bio');
    expect(profile.friendCount, 0);
    expect(profile.circleCount, 0);
    expect(profile.momentCount, 0);
    expect(profile.moments, isEmpty);
    expect(profile.imagePath, isNull);
  });

  testWidgets('Live profile does not display sample places or fake nearby friends',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final profile = repo.fromProfile(<String, dynamic>{
      'id': 'a2682c76-ab1d-47b2-a304-3d445111fed3',
      'display_name': 'Real User', 'bio': '',
    });
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      isLiveAccount: true,
      profile: profile,
      onTabSelected: (_) {},
      onAddPressed: () {},
      onRetry: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Your activity will appear here'), findsOneWidget);
    expect(find.text('Santa Monica'), findsNothing);
    expect(find.text('2 friends nearby'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editing real profile updates account display and retains navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _FakeProfileRepository();
    await tester.pumpWidget(MaterialApp(home: OrbitMyProfileScreen(
      repository: fake,
      onTabSelected: (_) {},
      onAddPressed: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Real User'), findsWidgets);
    await tester.tap(find.byKey(ProfileKeys.settingsButton));
    await tester.pumpAndSettle();
    final edit = find.text('Edit Profile');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byKey(EditProfileKeys.fullNameField), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Updated Person');
    await tester.enterText(find.byType(TextField).at(1), 'updated.person');
    await tester.enterText(find.byType(TextField).at(2), 'Community builder');
    await tester.ensureVisible(find.byKey(EditProfileKeys.saveButton));
    await tester.tap(find.byKey(EditProfileKeys.saveButton));
    await tester.pumpAndSettle();
    expect(fake.record['display_name'], 'Updated Person');
    expect(fake.record['username'], 'updated.person');
    expect(fake.record['bio'], 'Community builder');
    expect(find.text('Updated Person'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Privacy settings change only after server acknowledgement',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<PrivacySettings>();
    var requested = 0;
    await tester.pumpWidget(MaterialApp(home: PrivacySettingScreen(
      initialSettings: PrivacySettings.safeDefaults,
      onSaveSettings: (next) {
        requested++;
        return pending.future;
      },
    )));
    final row = find.byKey(PrivacySettingKeys.ghostModeRow);
    await tester.scrollUntilVisible(row, 220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pump();
    expect(requested, 1);
    expect(tester.widget<CircleSettingToggle>(
      find.byKey(PrivacySettingKeys.ghostModeToggle)).value, true);
    pending.complete(PrivacySettings.safeDefaults.copyWith(ghostModeEnabled: false));
    await tester.pump();
    expect(tester.widget<CircleSettingToggle>(
      find.byKey(PrivacySettingKeys.ghostModeToggle)).value, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed privacy writes preserve confirmed safe settings',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: PrivacySettingScreen(
      initialSettings: PrivacySettings.safeDefaults,
      onSaveSettings: (_) async => throw StateError('network down'),
    )));
    final row = find.byKey(PrivacySettingKeys.ghostModeRow);
    await tester.scrollUntilVisible(row, 220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.widget<CircleSettingToggle>(
      find.byKey(PrivacySettingKeys.ghostModeToggle)).value, true);
    expect(find.textContaining('previous settings remain active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SOS safety alerts are visually separate from social alerts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: NotificationScreen(
      initialSettings: NotificationSettings.demo,
    )));
    expect(find.text('SOS & Safety alerts'), findsOneWidget);
    expect(find.textContaining('Safety alerts are managed separately'), findsOneWidget);
  });

  testWidgets('A newly verified pending-deletion user may review and cancel',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _FakeDeletionClient();
    await tester.pumpWidget(MaterialApp(
      routes: <String, WidgetBuilder>{
        '/home': (_) => const Scaffold(body: Text('Account access restored')),
      },
      home: OrbitAccountDeletionStatusScreen(identity: fake),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your account is scheduled for deletion'), findsOneWidget);
    expect(find.textContaining('NOT yet been erased'), findsOneWidget);
    await tester.tap(find.text('Cancel deletion request'));
    await tester.pumpAndSettle();
    expect(fake.cancelled, true);
    expect(find.text('Account access restored'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Notification values round trip through backend JSON contract', () {
    const value = NotificationSettings(
      pushNotificationsEnabled: false,
      pingNotificationsEnabled: true,
      momentsNotificationsEnabled: false,
      circleUpdatesEnabled: true,
      sosAlertsEnabled: true,
      soundEnabled: false,
      vibrationEnabled: true,
    );
    final json = OrbitProfileSettingsRepository.notificationsToJson(value);
    final decoded = OrbitProfileSettingsRepository.notificationsFromJson(
      Map<String, dynamic>.from(json),
    );
    expect(decoded.pushNotificationsEnabled, false);
    expect(decoded.pingNotificationsEnabled, true);
    expect(decoded.circleUpdatesEnabled, true);
    expect(decoded.soundEnabled, false);
  });

  test('Privacy defaults do not reveal location', () {
    final empty = OrbitProfileSettingsRepository.privacyFromJson({});
    expect(empty.locationVisibility, 'Nobody');
    expect(empty.locationActivity, 'Off');
    expect(empty.locationSharingEnabled, false);
    expect(empty.ghostModeEnabled, true);
    const update = PrivacySettings(
      locationVisibility: 'Friends',
      locationActivity: 'While moving',
      locationSharingEnabled: false,
      ghostModeEnabled: true,
    );
    final roundTrip = OrbitProfileSettingsRepository.privacyFromJson(
      Map<String, dynamic>.from(
        OrbitProfileSettingsRepository.privacyToJson(update),
      ),
    );
    expect(roundTrip, update);
  });
}
