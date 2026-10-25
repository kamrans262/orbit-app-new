import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_repository.dart';
import 'package:orbit_ui/features/moments/presentation/screens/orbit_live_moment_viewer.dart';

final class _FakeMoments extends OrbitMomentRepository {
  bool authorized=true;
  String? activeUser;
  bool removedMoment=false;

  @override
  Future<String?> currentUserId() async => activeUser;

  @override
  Future<void> delete(OrbitLiveMoment moment) async {
    removedMoment=true;
  }

  static final Uint8List _pixel=Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAOEGFykAAAAASUVORK5CYII='));

  @override
  Future<bool> remainsAuthorized(OrbitLiveMoment moment) async => authorized;

  @override
  Future<Uint8List> photo(OrbitLiveMoment moment,{String variant='thumbnail'}) async =>
    Uint8List.fromList(_pixel);

  @override
  Future<String?> caption(OrbitLiveMoment moment) async => 'Private Moment caption';

  @override
  Future<void> view(OrbitLiveMoment moment) async {}
}

void main() {
  testWidgets('M7 shows owner-only deletion and never offers self-account report',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments()..activeUser='owner-uuid';
    final item=OrbitLiveMoment(id:'moment-owned',creatorId:'owner-uuid',
      mediaId:'media-test-uuid',contextId:'self',
      publishedAt:DateTime.utc(2026,10,25));
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(
      moment:item,repository:repo,author:'You')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage Moment'),findsOneWidget);
    expect(find.byTooltip('Report account'),findsNothing);
    await tester.tap(find.byTooltip('Manage Moment'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Moment'),findsOneWidget);
    expect(find.text('Change audience'),findsOneWidget);
    expect(find.text('Edit caption'),findsOneWidget);
  });

  testWidgets('M7 non-owner sees reporting actions but never deletion',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments()..activeUser='someone-else';
    final item=OrbitLiveMoment(id:'moment-shared',creatorId:'owner-uuid',
      mediaId:'media-test-uuid',contextId:'friends',
      publishedAt:DateTime.utc(2026,10,25));
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(
      moment:item,repository:repo,author:'Orbit member')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete this Moment'),findsNothing);
    expect(find.byTooltip('Report account'),findsOneWidget);
  });

  testWidgets('Stage 4 hides decrypted viewer content on audience revocation',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments();
    final item=OrbitLiveMoment(id:'moment-test-uuid',creatorId:'owner-uuid',
      mediaId:'media-test-uuid',contextId:'friends',
      publishedAt:DateTime.utc(2026,10,25));
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(
      moment:item,repository:repo,author:'Orbit author')));
    await tester.pumpAndSettle();
    expect(find.text('Private Moment caption'),findsOneWidget);
    repo.authorized=false;
    await tester.pump(const Duration(seconds:21));
    await tester.pumpAndSettle();
    expect(find.text('Private Moment caption'),findsNothing);
    expect(find.textContaining('unavailable or access has changed'),findsOneWidget);
    expect(find.byType(Image),findsNothing);
  });

  testWidgets('Stage 4 evicts visible decrypted caption on app background',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments();
    final item=OrbitLiveMoment(id:'moment-test-uuid',creatorId:'owner-uuid',
      mediaId:'media-test-uuid',contextId:'self',
      publishedAt:DateTime.utc(2026,10,25));
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(
      moment:item,repository:repo,author:'You')));
    await tester.pumpAndSettle();
    expect(find.text('Private Moment caption'),findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Private Moment caption'),findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Private Moment caption'),findsOneWidget);
  });
}
