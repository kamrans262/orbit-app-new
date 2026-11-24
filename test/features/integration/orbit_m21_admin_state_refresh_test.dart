import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/notifications/data/orbit_notification_repository.dart';
import 'package:orbit_ui/features/notifications/presentation/orbit_live_notifications_screen.dart';
import 'package:orbit_ui/features/plans/data/orbit_plan_repository.dart';
import 'package:orbit_ui/features/plans/domain/orbit_plan_models.dart';
import 'package:orbit_ui/features/plans/presentation/screens/orbit_live_plans_screen.dart';
import 'package:orbit_ui/features/plans/presentation/screens/orbit_live_plan_detail_screen.dart';

class _Identity extends OrbitIdentityClient {
  @override
  Future<String?> currentLocalSocialOwner() async=>'member';
}

OrbitNotificationItem _notice(String title)=>OrbitNotificationItem(
  id:title,category:'friends',type:'friend.requested',title:title,body:'A notice',
  targetId:'opaque',createdAt:DateTime.utc(2026,11,24),read:false);

class _Notices extends OrbitNotificationRepository {
  bool paused=false;
  final oldPage=Completer<OrbitNotificationPage>();
  @override
  Future<OrbitNotificationPage> page({int limit=20,String? cursor,String? category}) async {
    if(cursor!=null)return oldPage.future;
    return paused?const OrbitNotificationPage([],null):
      OrbitNotificationPage([_notice('Current notice')],'cursor');
  }
}

OrbitPlan _plan({bool cancelled=false})=>OrbitPlan(
  id:'plan-id',title:'Existing plan',startsAt:DateTime.now().add(const Duration(days:2)),
  status:cancelled?'cancelled':'scheduled',revision:cancelled?2:1,
  organizerId:'member',organizerName:'Owner',myRsvp:'organizer',canEdit:!cancelled);

class _Plans extends OrbitPlanRepository {
  bool cancelled=false;
  bool cacheCleared=false;
  @override
  Future<OrbitPlanPage> list({String tab='upcoming',int limit=20,String? cursor}) async {
    if(cursor!=null)throw OrbitIdentityException('Access changed',403);
    return OrbitPlanPage([_plan()],'cursor');
  }
  @override
  Future<OrbitPlan> detail(String id) async=>_plan(cancelled:cancelled);
  @override
  Future<void> clearCachedPlans() async {cacheCleared=true;}
}

void main(){
  testWidgets('older inbox page cannot restore Admin-paused notices after refresh',(tester) async {
    final repo=_Notices();
    await tester.pumpWidget(MaterialApp(home:OrbitLiveNotificationsScreen(repository:repo,identity:_Identity())));
    await tester.pumpAndSettle();
    expect(find.text('Current notice'),findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pump();
    repo.paused=true;
    // Existing lifecycle refresh is authoritative, even while a page is pending.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('No notifications'),findsOneWidget);
    repo.oldPage.complete(OrbitNotificationPage([_notice('Stale notice')],null));
    await tester.pumpAndSettle();
    expect(find.text('Stale notice'),findsNothing);
    expect(find.text('Current notice'),findsNothing);
  });

  testWidgets('denied next Plan page clears previous authorized rows',(tester) async {
    final repo=_Plans();
    await tester.pumpWidget(MaterialApp(home:OrbitLivePlansScreen(repository:repo,identity:_Identity())));
    await tester.pumpAndSettle();
    expect(find.text('Existing plan'),findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Existing plan'),findsNothing);
    expect(find.text('Plans could not be verified. Reconnect and retry.'),findsOneWidget);
    expect(repo.cacheCleared,isTrue);
  });

  testWidgets('resumed Plan detail uses Admin-cancelled revision and removes edit actions',(tester) async {
    final repo=_Plans();
    await tester.pumpWidget(MaterialApp(home:OrbitLivePlanDetailScreen(planId:'plan-id',repository:repo,identity:_Identity())));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'),findsOneWidget);
    repo.cancelled=true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'),findsOneWidget);
    expect(find.text('Edit Plan'),findsNothing);
    expect(find.text('Cancel Plan'),findsNothing);
  });
}
