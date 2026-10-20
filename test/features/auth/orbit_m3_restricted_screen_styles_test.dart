import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_primary_button.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_account_deletion_status_screen.dart';
import 'package:orbit_ui/features/auth/presentation/screens/orbit_offline_profile_screen.dart';
import 'package:orbit_ui/features/auth/presentation/widgets/auth_card.dart';

class _RestrictedFakeIdentity extends OrbitIdentityClient {
  Map<String, dynamic> status = <String, dynamic>{
    'status': 'pending',
    'can_cancel': true,
    'eligible_for_erasure_at': '2026-12-01T00:00:00+00:00',
  };
  Map<String, dynamic>? offline = <String, dynamic>{
    'display_name': 'Saved Member',
    'username': 'saved.member',
    'bio': 'Offline biography',
  };
  int cancelCalls = 0;
  int clearCalls = 0;

  @override
  Future<Map<String, dynamic>> deletionStatus() async => status;

  @override
  Future<void> cancelDeletion() async { cancelCalls++; }

  @override
  Future<Map<String, dynamic>?> cachedProfileForOffline() async => offline;

  @override
  Future<OrbitRestoreState> restoreSession() async =>
      OrbitRestoreState.offlineProfile;

  @override
  Future<void> clearSession() async { clearCalls++; }
}

void main() {
  Future<void> phone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('Offline read-only keeps all saved fields in Orbit-styled card',
      (tester) async {
    await phone(tester);
    final fake = _RestrictedFakeIdentity();
    await tester.pumpWidget(MaterialApp(
      home: OrbitOfflineProfileScreen(identity: fake),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.byType(AppPrimaryButton), findsOneWidget);
    expect(find.text('OFFLINE • READ ONLY'), findsOneWidget);
    expect(find.text('Saved Member'), findsOneWidget);
    expect(find.text('@saved.member'), findsOneWidget);
    expect(find.text('Offline biography'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    final label = tester.widget<Text>(find.text('Saved Member'));
    expect(label.style?.fontFamily, AppTypography.fontFamily);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.background);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deletion request uses Orbit CTA and preserves cancel behavior',
      (tester) async {
    await phone(tester);
    final fake = _RestrictedFakeIdentity();
    await tester.pumpWidget(MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.home: (_) =>
            OrbitAccountDeletionStatusScreen(identity: fake),
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
      },
      home: const Scaffold(body: Text('Placeholder')),
    ));
    // Render the restricted screen through its own route without a duplicate
    // '/' entry in the navigator.
    await tester.state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.byType(AuthCard), findsOneWidget);
    expect(find.byType(AppPrimaryButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Cancel deletion request'), findsOneWidget);
    expect(find.textContaining('Your data has NOT yet been erased.'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last)
        .backgroundColor, AppColors.background);
    await tester.tap(find.text('Cancel deletion request'));
    await tester.pumpAndSettle();
    expect(fake.cancelCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deletion request stays non-actionable after cancel window closes',
      (tester) async {
    await phone(tester);
    final fake = _RestrictedFakeIdentity();
    fake.status = <String, dynamic>{
      'status': 'pending',
      'can_cancel': false,
      'eligible_for_erasure_at': '2026-12-01T00:00:00+00:00',
    };
    await tester.pumpWidget(MaterialApp(
      home: OrbitAccountDeletionStatusScreen(identity: fake),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cancel deletion request'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(fake.cancelCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
