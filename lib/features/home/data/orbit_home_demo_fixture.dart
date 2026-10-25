import 'package:flutter/foundation.dart';

import '../domain/models/home_models.dart';

/// Seed-style local UI fixtures, enabled by default ONLY for debug builds.
/// Never writes fake user, event or Moment records to the Laravel database.
/// The app's release/profile builds always hide these fixtures.
abstract final class OrbitHomeDemoFixture {
  static const bool requested = bool.fromEnvironment(
    'ORBIT_DEMO_HOME', defaultValue: true,
  );
  static bool get enabled => kDebugMode && requested;

  static bool isDemo(String id) => id.startsWith('demo-');

  static const participants = <ParticipantData>[
    ParticipantData(id:'demo-emma',name:'Emma',imagePath:'assets/Emma.png'),
    ParticipantData(id:'demo-mike',name:'Mike',imagePath:'assets/Mike.png'),
    ParticipantData(id:'demo-sophia',name:'Sophia',imagePath:'assets/Sophia.png'),
  ];

  static const upcomingPlans = <UpcomingPlanData>[
    UpcomingPlanData(
      id:'demo-plan-dinner',
      title:'Dinner Together · Demo',
      schedule:'Sample event · 7:00 PM',
      location:'Sample venue · Not an actual booking',
      participants:participants,
    ),
    UpcomingPlanData(
      id:'demo-plan-coffee',
      title:'Coffee Meetup · Demo',
      schedule:'Sample event · 10:30 AM',
      location:'Sample coffee shop · Not an actual booking',
      participants:participants,
    ),
    UpcomingPlanData(
      id:'demo-plan-hike',
      title:'Weekend Hike · Demo',
      schedule:'Sample event · Saturday 9:00 AM',
      location:'Sample trail · Not an actual booking',
      participants:participants,
    ),
  ];

  static const friends = <FavoritePersonData>[
    FavoritePersonData(id:'demo-emma',name:'Emma',status:'Demo profile',
      imagePath:'assets/Emma.png',isOnline:false),
    FavoritePersonData(id:'demo-mike',name:'Mike',status:'Demo profile',
      imagePath:'assets/Mike.png',isOnline:false),
    FavoritePersonData(id:'demo-sophia',name:'Sophia',status:'Demo profile',
      imagePath:'assets/Sophia.png',isOnline:false),
  ];

  static const recentMoments = <MomentData>[
    MomentData(id:'demo-moment-1',name:'Emma',timeLabel:'Demo photo',
      imagePath:'assets/m1.jpg',senderAvatarPath:'assets/Emma.png'),
    MomentData(id:'demo-moment-2',name:'Mike',timeLabel:'Demo photo',
      imagePath:'assets/m2.jpg',senderAvatarPath:'assets/Mike.png'),
    MomentData(id:'demo-moment-3',name:'Sophia',timeLabel:'Demo photo',
      imagePath:'assets/m3.jpg',senderAvatarPath:'assets/Sophia.png'),
  ];

  static const banner = PromoBannerData(
    id:'demo-promo',
    backgroundImagePath:'assets/banner.png',
    logoImagePath:'assets/bannerlogo.png',
    title:'Sample promotion · Demo',
    subtitle:'Visual preview only · No real offer',
  );
}
