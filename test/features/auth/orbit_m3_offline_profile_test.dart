import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/auth/data/orbit_offline_profile_snapshot.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_offline_profile_screen.dart';

class _OfflineFakeClient extends OrbitIdentityClient {
  Map<String, dynamic>? cached;
  OrbitRestoreState next = OrbitRestoreState.offlineProfile;
  bool cleared = false;

  @override
  Future<Map<String, dynamic>?> cachedProfileForOffline() async => cached;

  @override
  Future<OrbitRestoreState> restoreSession() async => next;

  @override
  Future<void> clearSession() async { cleared = true; }
}

void main() {
  const owner = 'a184ec0b-5f71-4e75-a142-b04c36c07859';
  final now = DateTime.utc(2026, 10, 20, 12);
  const profile = <String, dynamic>{
    'id': owner, 'display_name': 'Real Member',
    'username': 'real.member', 'bio': 'Private bio',
    'refresh_token': 'not for cache',
    'privacy': <String, Object>{'location_visibility': 'Friends'},
  };

  test('Encrypted-only profile snapshot excludes secrets and preferences', () {
    final encoded = OrbitOfflineProfileSnapshot.encode(profile, now);
    expect(encoded, isNot(contains('not for cache')));
    expect(encoded, isNot(contains('location_visibility')));
    final read = OrbitOfflineProfileSnapshot.read(encoded,
      owner: owner, sessionPresent: true, now: now.add(const Duration(minutes: 45)));
    expect(read?['display_name'], 'Real Member');
    expect(read?['_offline_cached'], true);
  });

  test('Offline cache rejects cross-account, expired, future or missing sessions', () {
    final encoded = OrbitOfflineProfileSnapshot.encode(profile, now);
    for (final invalid in <Map<String, dynamic>>[
      <String,dynamic>{'owner':'other-account','session':true,
        'when':now},
      <String,dynamic>{'owner':owner,'session':false,'when':now},
      <String,dynamic>{'owner':owner,'session':true,
        'when':now.add(const Duration(hours: 1, seconds: 1))},
      <String,dynamic>{'owner':owner,'session':true,
        'when':now.subtract(const Duration(seconds: 1))},
    ]) {
      final read = OrbitOfflineProfileSnapshot.read(encoded,
        owner: invalid['owner'] as String,
        sessionPresent: invalid['session'] as bool,
        now: invalid['when'] as DateTime);
      expect(read, isNull);
    }
    expect(OrbitOfflineProfileSnapshot.read('{invalid',owner:owner,
        sessionPresent:true,now:now),isNull);
    expect(OrbitOfflineProfileSnapshot.read('[]',owner:owner,
        sessionPresent:true,now:now),isNull);
  });

  testWidgets('Offline profile is read-only and reconnects only after verified server state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _OfflineFakeClient()..cached = <String,dynamic>{
      'id':owner,'display_name':'Real Member','username':'real.member',
      'bio':'Private bio','_offline_cached':true,
    };
    await tester.pumpWidget(MaterialApp(
      routes:<String,WidgetBuilder>{
        AppRoutes.home: (_) => const Scaffold(body:Text('Verified Home')),
        AppRoutes.welcome: (_) => const Scaffold(body:Text('Welcome')),
      },
      home: OrbitOfflineProfileScreen(identity:fake),
    ));
    await tester.pumpAndSettle();
    expect(find.text('OFFLINE • READ ONLY'), findsOneWidget);
    expect(find.text('Real Member'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.textContaining('privacy changes'), findsNothing);
    expect(find.text('Verified Home'), findsNothing);
    await tester.tap(find.text('Reconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Verified Home'), findsNothing);
    fake.next = OrbitRestoreState.authenticated;
    await tester.tap(find.text('Reconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Verified Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign out invalidates offline-only account preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = _OfflineFakeClient()..cached = <String,dynamic>{
      'id':owner,'display_name':'Real Member','username':'real.member',
      'bio':'','_offline_cached':true,
    };
    await tester.pumpWidget(MaterialApp(
      routes:<String,WidgetBuilder>{
        AppRoutes.welcome: (_) => const Scaffold(body:Text('Welcome')),
      },
      home: OrbitOfflineProfileScreen(identity:fake),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out and clear offline data'));
    await tester.pumpAndSettle();
    expect(fake.cleared, true);
    expect(find.text('Welcome'), findsOneWidget);
  });
}
