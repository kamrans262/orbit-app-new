import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_repository.dart';
import 'package:orbit_ui/features/moments/presentation/screens/orbit_live_moment_viewer.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/orbit_moment_comment_components.dart';
import 'package:orbit_ui/core/widgets/app_screen_header.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';

final class _FakeMoments extends OrbitMomentRepository {
  bool authorized=true;
  String? activeUser;
  bool removedMoment=false;
  int sent=0;
  @override
  Future<List<({String id,String author,String body,String? parent})>> allComments(OrbitLiveMoment item,{int max=150}) async => [];
  @override
  Future<String> commentWithReceipt(OrbitLiveMoment item,String text,{String? parent}) async {sent++;return 'confirmed-comment';}

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
  testWidgets('small authorized photo expands to the existing viewer width',(tester)async{
    await tester.binding.setSurfaceSize(const Size(360,640));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments()..activeUser='viewer';
    final item=OrbitLiveMoment(id:'small-photo',creatorId:'owner',mediaId:'media',
      contextId:'friends',publishedAt:DateTime.now());
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(
      moment:item,repository:repo,author:'Friend')));
    await tester.pumpAndSettle();
    final photo=find.byType(Image);
    expect(photo,findsOneWidget);
    expect(tester.getSize(photo).width,320);
    expect(tester.getSize(photo).height,greaterThan(250));
    expect(tester.widget<Image>(photo).fit,BoxFit.contain);
    final screen=tester.getRect(find.byType(Scaffold));
    final header=tester.getRect(find.byType(AppScreenHeader));
    final like=tester.getRect(find.byIcon(Icons.favorite_border_rounded));
    expect(header.top-screen.top,12);
    expect(tester.getRect(photo).top-header.bottom,12);
    // The 20px icon sits in its existing 40px button.
    expect(screen.bottom-like.bottom,22);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

  testWidgets('story tap navigation crosses creators and pauses on hold',(tester) async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments()..activeUser='viewer';
    final first=OrbitLiveMoment(id:'first',creatorId:'a',mediaId:'a-media',contextId:'friends',publishedAt:DateTime.now());
    final second=OrbitLiveMoment(id:'second',creatorId:'b',mediaId:'b-media',contextId:'friends',publishedAt:DateTime.now());
    final seen=<String>[];
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(moment:first,repository:repo,
      author:'First',playlist:[first,second],authorNames:const {'a':'First','b':'Second'},onViewed:seen.add)));
    // Do not settle a running five-second story animation.
    for(var i=0;i<5;i++)await tester.pump();
    expect(seen,['first']);
    expect(find.text('First'),findsOneWidget);
    final image=find.byType(Image).first;
    final rect=tester.getRect(image);
    final touch=await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds:650));
    await tester.pump(const Duration(seconds:6));
    expect(seen,['first']);
    await touch.up();await tester.pump();
    // A contained portrait/landscape image may be centered in a wider
    // gesture region. Tap the right half of the actual viewer viewport.
    final viewport=tester.getRect(find.byType(Scaffold).first);
    await tester.tapAt(Offset(viewport.right-28,rect.center.dy));
    for(var i=0;i<5;i++)await tester.pump();
    expect(seen,['first','second']);
    expect(find.text('Second'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('comments expand inline and show only a confirmed sent comment',(tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_FakeMoments()..activeUser='viewer';
    final item=OrbitLiveMoment(id:'moment-comments',creatorId:'owner',mediaId:'media',contextId:'friends',
      publishedAt:DateTime.now());
    await tester.pumpWidget(MaterialApp(home:OrbitLiveMomentViewer(moment:item,repository:repo,author:'Friend',openComments:true)));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitMomentCommentsHeader),findsOneWidget);
    expect(find.byType(OrbitMomentCommentComposer),findsOneWidget);
    final input=tester.widget<TextField>(find.byType(TextField));
    expect(input.style?.fontSize,12);
    expect(input.decoration?.fillColor,AppColors.white);
    await tester.enterText(find.byType(TextField),'Great moment');
    await tester.ensureVisible(find.byIcon(Icons.send_rounded));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(repo.sent,1);
    expect(find.text('Great moment'),findsOneWidget);
    expect(find.byType(OrbitMomentCommentRow),findsOneWidget);
    expect(find.byTooltip('Report this private comment'),findsOneWidget);
    expect(find.byType(OrbitMomentCommentsHeader),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
