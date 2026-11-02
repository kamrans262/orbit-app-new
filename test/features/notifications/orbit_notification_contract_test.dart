import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/routing/app_routes.dart';
import 'package:orbit_ui/features/notifications/data/orbit_notification_repository.dart';

void main() {
  test('M14 parses a generic server-authorized notice', () {
    final item=OrbitNotificationItem.fromJson({
      'id':'notice-1','category':'messages','type':'message.available',
      'title':'New message','body':'You have a new message in Orbit.',
      'created_at':'2026-11-02T10:00:00Z','read':false,
      'target':{'kind':'messages','opaque_id':'message-1'},
    });
    expect(item.category,'messages');
    expect(item.title,'New message');
    expect(item.targetId,'message-1');
    expect(item.read,isFalse);
  });
  test('M14 fails closed on unsupported or mismatched private targets', () {
    final base=<String,dynamic>{
      'id':'a','category':'pings','type':'ping.received',
      'title':'New Ping','body':'You have a Ping.',
      'created_at':'2026-11-02T10:00:00Z','read':false,
      'target':{'kind':'pings','opaque_id':'ping-1'},
    };
    expect(()=>OrbitNotificationItem.fromJson({
      ...base,'category':'location',
    }),throwsFormatException);
    expect(()=>OrbitNotificationItem.fromJson({
      ...base,'target':{'kind':'messages','opaque_id':'ping-1'},
    }),throwsFormatException);
    expect(()=>OrbitNotificationItem.fromJson({
      ...base,'created_at':'invalid',
    }),throwsFormatException);
    expect(()=>OrbitNotificationItem.fromJson({
      ...base,'read':'false',
    }),throwsFormatException);
  });
  test('Opaque grouping reference is accepted only as a digest', () {
    final item=OrbitNotificationItem.fromJson({
      'id':'notification-id','category':'messages','type':'message.available',
      'title':'New message','body':'You have a message.',
      'group_key':'a'*64,'created_at':'2026-11-02T10:00:00Z',
      'read':false,'target':{'kind':'messages','opaque_id':'message-id'},
    });
    expect(item.groupKey,'a'*64);
    expect(()=>OrbitNotificationItem.fromJson({
      'id':'notification-id','category':'messages','type':'message.available',
      'title':'New message','body':'You have a message.',
      'group_key':'raw-conversation-id','created_at':'2026-11-02T10:00:00Z',
      'read':false,'target':{'kind':'messages','opaque_id':'message-id'},
    }),throwsFormatException);
  });

  test('Onboarding permission and authenticated inbox use distinct routes', () {
    expect(AppRoutes.notifications,'/notifications');
    expect(AppRoutes.notificationInbox,'/inbox/notifications');
    expect(AppRoutes.notificationInbox,isNot(AppRoutes.notifications));
  });
}
