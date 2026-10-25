import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/presentation/screens/friend_details_screen.dart';
import 'package:orbit_ui/features/circles/domain/models/friend_details_models.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_repository.dart';
import 'package:orbit_ui/features/moments/domain/models/moments_models.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moments_screen.dart';
import 'package:orbit_ui/features/profile/presentation/screens/orbit_live_profile_moments.dart';

class _PrivateMoments extends OrbitMomentRepository {
  bool eligible=true;
  int checks=0;
  final moment=OrbitLiveMoment(
    id:'moment-001',creatorId:'author-001',mediaId:'media-001',
    contextId:'circle:test',publishedAt:DateTime.utc(2026,10,25),
  );
  static final image=Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAOEGFykAAAAASUVORK5CYII='));
  @override
  Future<List<OrbitLiveMoment>> feed({
    bool rail=false,String? circleId,String? profileId,int maxItems=120,
  }) async => [moment];

  @override
  Future<Uint8List> photo(OrbitLiveMoment item,{
    String variant='thumbnail',
  }) async => Uint8List.fromList(image);

  @override
  Future<bool> remainsAuthorized(OrbitLiveMoment item) async {
    checks++;
    return eligible;
  }

  @override
  Future<String> name(String id) async => 'Circle member';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Circle Members and Moments stay in the existing detail screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:FriendDetailsScreen(
      circleName:'Private Circle',
      members:const <FriendMemberData>[],
      groups:const <CircleGroupData>[],
      onBack:(){},
      onAddMember:(){},
      showGroupSegment:false,
      momentsTabBuilder:(_)=>const Text('Authorized Circle Moments'),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('circle_detail_members_tab')),findsOneWidget);
    expect(find.byKey(const Key('circle_detail_moments_tab')),findsOneWidget);
    expect(find.text('No members in this circle yet.'),findsOneWidget);
    await tester.tap(find.byKey(const Key('circle_detail_moments_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Authorized Circle Moments'),findsOneWidget);
    expect(find.text('Private Circle'),findsOneWidget);
    await tester.tap(find.byKey(const Key('circle_detail_members_tab')));
    await tester.pumpAndSettle();
    expect(find.text('No members in this circle yet.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Circle Moment grid removes decoded content when ACL revoked',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_PrivateMoments();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:OrbitLiveProfileMoments(
        circleId:'circle-001',repository:repo)),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(Image),findsWidgets);
    repo.eligible=false;
    await tester.pump(const Duration(seconds:26));
    await tester.pumpAndSettle();
    expect(find.byType(Image),findsNothing);
    expect(find.text('No Moments yet'),findsOneWidget);
    expect(repo.checks,greaterThan(1));
  });

  testWidgets('M7 feed presents a real continuation control', (tester) async {
    var loads=0;
    await tester.binding.setSurfaceSize(const Size(390,844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home:MomentsScreen(
      stories:const [],
      feedItems:const [
        MomentTextFeedItem(
          id:'moment-one',
          author:MomentAuthorData(id:'creator-1',name:'Orbit member'),
          timeLabel:'Just now',
          text:'Encrypted content preview',
        ),
      ],
      privateMode:true,
      onSearchPressed:(){},onFilterPressed:(){},
      onMessagesPressed:(){},onStoryPressed:(_){},
      onLikeChanged:(_,__){},onCommentPressed:(_){},
      onBookmarkChanged:(_,__){},onSharePressed:(_){},
      onTextMenuPressed:(_){},onFeedItemPressed:(_){},
      onTabSelected:(_){},onAddPressed:(){},
      hasMore:true,onLoadMore:()=>loads++,
    )));
    await tester.pumpAndSettle();
    final more=find.byKey(const Key('moments_load_more'));
    expect(more,findsOneWidget);
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(loads,1);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Circle Moment thumbnails disappear on app background',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_PrivateMoments();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:OrbitLiveProfileMoments(
        circleId:'circle-001',repository:repo)),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(Image),findsWidgets);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(Image),findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(Image),findsWidgets);
  });
}
