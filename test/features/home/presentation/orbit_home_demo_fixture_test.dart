import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/data/orbit_home_demo_fixture.dart';

void main() {
  test('Demo Home content is debug-only and never represents backend IDs', () {
    expect(OrbitHomeDemoFixture.enabled, kDebugMode);
    expect(OrbitHomeDemoFixture.upcomingPlans.length, greaterThanOrEqualTo(2));
    expect(OrbitHomeDemoFixture.upcomingPlans.every(
      (plan) => OrbitHomeDemoFixture.isDemo(plan.id) &&
        plan.title.contains('Demo') &&
        plan.location!.contains('Not an actual booking') &&
        plan.participants.isNotEmpty,
    ), isTrue);
    expect(OrbitHomeDemoFixture.friends.every(
      (person) => OrbitHomeDemoFixture.isDemo(person.id) &&
        person.status == 'Demo profile' &&
        person.isOnline == false &&
        person.imagePath.startsWith('assets/'),
    ), isTrue);
    expect(OrbitHomeDemoFixture.recentMoments.every(
      (moment) => OrbitHomeDemoFixture.isDemo(moment.id) &&
        moment.timeLabel == 'Demo photo' &&
        moment.encryptedImageBytes == null &&
        moment.imagePath.startsWith('assets/'),
    ), isTrue);
  });
}
