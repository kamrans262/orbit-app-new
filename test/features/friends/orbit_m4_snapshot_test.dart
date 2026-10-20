import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/friends/data/orbit_friend_snapshot.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';

void main() {
  final at = DateTime.utc(2026,10,20,13);
  const people = <OrbitPerson>[
    OrbitPerson(id:'u1',name:'Ayesha',username:'ayesha',relationship:'friend'),
    OrbitPerson(id:'u2',name:'Omar',username:'omar',relationship:'friend'),
  ];
  test('secure snapshot is owner-bound, age-limited and strips relationships', () {
    final encoded = OrbitFriendSnapshot.encode('owner-a',people,at);
    expect(encoded,contains('Ayesha'));
    expect(encoded, isNot(contains('friend')));
    final good = OrbitFriendSnapshot.decode(encoded,'owner-a',at.add(const Duration(minutes:14)));
    expect(good, isNotNull);
    expect(good!.people.length,2);
    expect(good.people.first.relationship,'none');
    expect(OrbitFriendSnapshot.decode(encoded,'owner-b',at),isNull);
    expect(OrbitFriendSnapshot.decode(encoded,'owner-a',at.add(const Duration(minutes:16))),isNull);
    expect(OrbitFriendSnapshot.decode(encoded,'owner-a',at.subtract(const Duration(seconds:1))),isNull);
  });
  test('corrupt or oversized snapshot never grants offline access', () {
    expect(OrbitFriendSnapshot.decode('broken','user',at),isNull);
    expect(OrbitFriendSnapshot.decode('x' * 100000,'user',at),isNull);
    expect(OrbitFriendSnapshot.decode(null,'user',at),isNull);
  });
}
