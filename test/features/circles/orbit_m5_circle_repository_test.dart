import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_repository.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_snapshot.dart';

void main() {
  test('Circle metadata never fabricates sharing, location or presence', () {
    final c=OrbitCircle.fromJson({
      'id':'circle-uuid','name':'Private',
      'owner_id':'member-1','role':'admin','member_count':3,'revision':5,
      'capabilities':{'invite':true,'edit':false},
    });
    expect(c.can('invite'),isTrue);
    expect(c.can('edit'),isFalse);
    expect(c.can('location'),isFalse);
    expect(c.memberCount,3);
  });

  test('Invitation codes are strictly recipient-code length and official host', () {
    final repo=OrbitCircleRepository();
    const code='ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCD';
    expect(code.length,40);
    expect(repo.validateCode(code),code);
    expect(repo.validateCode(
      'https://indigo-caribou-178970.hostingersite.com/invite/circle/$code'),code);
    expect(()=>repo.validateCode('https://evil.example/invite/circle/$code'),
      throwsFormatException);
    expect(()=>repo.validateCode('abc'),throwsFormatException);
    expect(()=>repo.validateCode('https://indigo-caribou-178970.hostingersite.com/invite/circle/$code?q=1'),
      throwsFormatException);
  });

  test('Circle snapshot keeps names only and refuses other owners/stale data', () {
    final now=DateTime.utc(2026,10,21,12);
    const circle=OrbitCircle(
      id:'c1',name:'Family',ownerId:'u1',role:'owner',
      memberCount:14,revision:9,
      capabilities:{'invite':true});
    final encoded=OrbitCircleSnapshot.encode('alice',[circle],now);
    expect(encoded,contains('Family'));
    expect(encoded, isNot(contains('memberCount')));
    expect(encoded, isNot(contains('invite')));
    expect(encoded, isNot(contains('ownerId')));
    final snapshot=OrbitCircleSnapshot.decode(
      encoded,'alice',now.add(const Duration(minutes:10)));
    expect(snapshot?.circles.single.name,'Family');
    expect(snapshot?.circles.single.memberCount,0);
    expect(OrbitCircleSnapshot.decode(encoded,'bob',now),isNull);
    expect(OrbitCircleSnapshot.decode(
      encoded,'alice',now.add(const Duration(minutes:16))),isNull);
  });
}
