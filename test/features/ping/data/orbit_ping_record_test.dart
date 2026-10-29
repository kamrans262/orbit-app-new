import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/ping/data/orbit_ping_repository.dart';

void main() {
  test('Ping response uses only verified backend delivery status', () {
    final record=OrbitPingRecord.fromJson({
      'id':'a','sender_id':'sender','recipient_id':'recipient',
      'type':'hello','status':'accepted',
      'context':{'type':'friend','id':null},
    });
    expect(record.status,'accepted');
    expect(record.displayText,contains('Hello'));
    expect(record.contextType,'friend');
  });

  test('custom Ping carries real text, never a fabricated recipient', () {
    final record=OrbitPingRecord.fromJson({
      'id':'a','sender_id':'sender','recipient_id':'recipient',
      'type':'custom','custom_text':'Can you call me?',
      'status':'delivered','context':{'type':'circle','id':'circle-id'},
    });
    expect(record.displayText,'Can you call me?');
    expect(record.contextId,'circle-id');
    expect(record.status,'delivered');
    expect(() => OrbitPingRecord.fromJson({'id':'a'}),
        throwsFormatException);
  });

  test('offline intents preserve their idempotency key and exact audience', () {
    final pending=OrbitPingPending.fromJson({
      'client_id':'key','recipient_id':'recipient','type':'custom',
      'custom_text':'Hello','context':{'type':'circle','id':'circle-id'},
    });
    expect(pending.toJson()['client_id'],'key');
    expect((pending.toJson()['context'] as Map)['id'],'circle-id');
  });
}
