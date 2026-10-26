import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../orbit/presentation/screens/orbit_screen.dart';
import '../../../moments/presentation/screens/orbit_live_moments_screen.dart';
import '../../../moments/presentation/orbit_moment_camera_launcher.dart';
import '../../../profile/presentation/navigation/profile_navigation.dart';
import '../../domain/models/home_models.dart';
import '../widgets/home_circle_avatar_tile.dart';
import '../widgets/home_circle_summary_tile.dart';
import '../widgets/home_recent_moment_tile.dart';
import '../widgets/promo_banner_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/upcoming_plan_card.dart';

import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../circles/presentation/screens/friend_details_screen.dart';
import '../../../circles/domain/models/friend_details_models.dart';
import '../../../friends/presentation/screens/orbit_discover_friends_screen.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../requests/presentation/screens/request_screen.dart';
import '../../../../core/widgets/app_emoji_safe_text.dart';

abstract final class HomeKeys {
  static const greeting = Key('home_greeting');
  static const findFriendsButton = Key('home_find_friends_button');
  static const notificationButton = Key('home_notification_button');
  static const quickActionsList = Key('home_quick_actions_list');
  static const recentMomentsList = Key('home_recent_moments_list');
  static const circlesList = Key('home_m8_circles_list');
  static const bottomNavigation = Key('home_bottom_navigation');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.greetingName,
    required this.quickActions,
    required this.upcomingPlans,
    required this.promoBanner,
    required this.favoritePeople,
    required this.recentMoments,
    required this.onNotificationPressed,
    required this.onQuickActionPressed,
    required this.onPlanPressed,
    required this.onPromoPressed,
    required this.onFavoritePersonPressed,
    required this.onFavoriteToggle,
    required this.onMomentPressed,
    required this.onTabSelected,
    required this.onAddPressed,
    this.nearbyFriendsCount,
    this.circleSummaries = const <HomeCircleSummaryData>[],
    this.onCirclePressed,
    this.onSeeAllCirclesPressed,
    this.showCircleSection = false,
    this.peopleSectionTitle = 'Your Circle',
    this.planUnavailable = false,
    this.dashboardNotice,
    this.onDashboardRetry,
    this.onSeeAllPlansPressed,
    this.onSeeAllFriendsPressed,
    this.onSeeAllMomentsPressed,
    this.selectedBottomIndex = 0,
    this.isLoading = false,
    this.useLiveDate = false,
    this.enableDemoCircleNavigation = false,
    this.enableDemoOrbitNavigation = false,
    super.key,
  });

  factory HomeScreen.demo({
    VoidCallback? onNotificationPressed,
    ValueChanged<int>? onTabSelected,
    VoidCallback? onAddPressed,
    bool enableDemoCircleNavigation = true,
    List<MomentData>? realRecentMoments,
    ValueChanged<MomentData>? onRealMomentPressed,
  }) {
    const participants = <ParticipantData>[
      ParticipantData(id: 'emma', name: 'Emma', imagePath: 'assets/Emma.png'),
      ParticipantData(id: 'mike', name: 'Mike', imagePath: 'assets/Mike.png'),
      ParticipantData(
        id: 'sophia',
        name: 'Sophia',
        imagePath: 'assets/Sophia.png',
      ),
      ParticipantData(id: 'emma-2', name: 'Emma', imagePath: 'assets/Emma.png'),
      ParticipantData(id: 'mike-2', name: 'Mike', imagePath: 'assets/Mike.png'),
    ];

    return HomeScreen(
      nearbyFriendsCount: 2,
      greetingName: 'Emma',
      quickActions: const <QuickActionData>[
        QuickActionData(
          id: 'ping',
          title: 'Ping',
          icon: Icons.bolt_rounded,
          iconColor: Color(0xFF7C3AED),
          iconBackground: Color(0xFFF2EAFE),
        ),
        QuickActionData(
          id: 'sos',
          title: 'SOS',
          icon: Icons.sos_rounded,
          iconColor: Color(0xFFF43F8E),
          iconBackground: Color(0xFFFFE1EE),
        ),
        QuickActionData(
          id: 'explore',
          title: 'Explore',
          icon: Icons.explore_outlined,
          iconColor: Color(0xFF4978F2),
          iconBackground: Color(0xFFE7EDFF),
        ),
        QuickActionData(
          id: 'moment',
          title: 'Moment',
          icon: Icons.photo_camera_outlined,
          iconColor: Color(0xFF16B88B),
          iconBackground: Color(0xFFE2F8F2),
        ),
      ],
      upcomingPlans: const <UpcomingPlanData>[
        UpcomingPlanData(
          id: 'dinner',
          title: 'Dinner Together',
          schedule: 'Today â€¢ 7:00 PM',
          location: 'Luna Bistro, San Francisco',
          participants: participants,
        ),
      ],
      promoBanner: const PromoBannerData(
        id: 'ride',
        backgroundImagePath: 'assets/banner.png',
        logoImagePath: 'assets/bannerlogo.png',
        title: 'Get there together',
        subtitle: 'Ride with friends',
      ),
      favoritePeople: const <FavoritePersonData>[
        FavoritePersonData(
          id: 'emma',
          name: 'Emma',
          status: 'Active now',
          imagePath: 'assets/Emma.png',
        ),
        FavoritePersonData(
          id: 'mike',
          name: 'Mike',
          status: 'Active 5m ago',
          imagePath: 'assets/Mike.png',
        ),
        FavoritePersonData(
          id: 'sophia',
          name: 'Sophia',
          status: 'Active 12m ago',
          imagePath: 'assets/Sophia.png',
        ),
      ],
      recentMoments: realRecentMoments ?? const <MomentData>[
        MomentData(
          id: 'm1',
          name: 'Finn',
          timeLabel: '1h ago',
          imagePath: 'assets/m1.jpg',
          senderAvatarPath: 'assets/Mike.png',
        ),
        MomentData(
          id: 'm2',
          name: 'Emma',
          timeLabel: '2h ago',
          imagePath: 'assets/m2.jpg',
          senderAvatarPath: 'assets/Emma.png',
        ),
        MomentData(
          id: 'm3',
          name: 'Mike',
          timeLabel: '3h ago',
          imagePath: 'assets/m3.jpg',
          senderAvatarPath: 'assets/Mike.png',
        ),
        MomentData(
          id: 'm4',
          name: 'Sophia',
          timeLabel: '5h ago',
          imagePath: 'assets/m4.jpg',
          senderAvatarPath: 'assets/Sophia.png',
        ),
      ],
      onNotificationPressed: onNotificationPressed ?? () {},
      onQuickActionPressed: (action) {},
      onPlanPressed: (plan) {},
      onPromoPressed: () {},
      onFavoritePersonPressed: (person) {},
      onFavoriteToggle: (person) {},
      onMomentPressed: onRealMomentPressed ?? (moment) {},
      onTabSelected: onTabSelected ?? (index) {},
      onAddPressed: onAddPressed ?? () {},
      enableDemoCircleNavigation:enableDemoCircleNavigation,
      enableDemoOrbitNavigation:enableDemoCircleNavigation,
    );
  }

  /// Only provided when the app has a genuine nearby-presence count.
  final int? nearbyFriendsCount;
  final List<HomeCircleSummaryData> circleSummaries;
  final ValueChanged<HomeCircleSummaryData>? onCirclePressed;
  final VoidCallback? onSeeAllCirclesPressed;
  final bool showCircleSection,planUnavailable;
  final String peopleSectionTitle;
  final String? dashboardNotice;
  final VoidCallback? onDashboardRetry;
  final VoidCallback? onSeeAllPlansPressed;
  final VoidCallback? onSeeAllFriendsPressed;
  final VoidCallback? onSeeAllMomentsPressed;
  final String greetingName;
  final List<QuickActionData> quickActions;
  final List<UpcomingPlanData> upcomingPlans;
  final PromoBannerData? promoBanner;
  final List<FavoritePersonData> favoritePeople;
  final List<MomentData> recentMoments;
  final VoidCallback onNotificationPressed;
  final ValueChanged<QuickActionData> onQuickActionPressed;
  final ValueChanged<UpcomingPlanData> onPlanPressed;
  final VoidCallback onPromoPressed;
  final ValueChanged<FavoritePersonData> onFavoritePersonPressed;
  final ValueChanged<FavoritePersonData> onFavoriteToggle;
  final ValueChanged<MomentData> onMomentPressed;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final int selectedBottomIndex;
  final bool isLoading;
  final bool useLiveDate;
  /// Preserves approved design-preview fixture behavior but never opens
  /// fabricated Circle rosters in authenticated production navigation.
  final bool enableDemoCircleNavigation;
  final bool enableDemoOrbitNavigation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  static const double _horizontalPadding = 15;
  static const double _sectionGap = 10;
}

class _HomeScreenState extends State<HomeScreen> {
  late List<FavoritePersonData> _favoritePeople;

  @override
  void initState() {
    super.initState();
    _favoritePeople = List<FavoritePersonData>.of(widget.favoritePeople);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.favoritePeople, widget.favoritePeople)) {
      _favoritePeople = List<FavoritePersonData>.of(widget.favoritePeople);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavigationBar(
        key: HomeKeys.bottomNavigation,
        selectedIndex: widget.selectedBottomIndex,
        onTabSelected: _handleBottomTabSelected,
        onAddPressed: _openMomentCamera,
      ),
      body: SafeArea(
        bottom: false,
        child: widget.isLoading ? const _HomeLoadingState() : _buildContent(),
      ),
    );
  }

  void _handleBottomTabSelected(int index) {
    if (index == 3) {
      unawaited(_openProfile());
      return;
    }
    if (index == 1) {
      _openOrbit();
      return;
    }
    if (index == 2) {
      _openMoments();
      return;
    }

    widget.onTabSelected(index);
  }

  Future<void> _openProfile() async {
    final targetIndex = await openProfileScreen(
      context: context,
      onAddPressed: _openMomentCamera,
    );
    if (!mounted || targetIndex == null) {
      return;
    }
    _handleBottomTabSelected(targetIndex);
  }

  void _openOrbit() {
    if (!widget.enableDemoOrbitNavigation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Explore is not available yet. No location was shared.'),
      ));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => OrbitScreen.demo(
          onTabSelected: (orbitIndex) {
            if (orbitIndex == 0) {
              Navigator.of(routeContext).pop();
              return;
            }
            widget.onTabSelected(orbitIndex);
          },
          onAddPressed: _openMomentCamera,
        ),
      ),
    );
  }

  void _openMoments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => OrbitLiveMomentsScreen(
          onTabSelected: (momentsIndex) {
            if (momentsIndex == 0) {
              Navigator.of(routeContext).pop();
              return;
            }
            if (momentsIndex == 1) {
              if (!widget.enableDemoOrbitNavigation) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:Text('Explore is not available yet. No location was shared.'),
                ));
                return;
              }
              Navigator.of(routeContext).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (orbitContext) => OrbitScreen.demo(
                    onTabSelected: (orbitIndex) {
                      if (orbitIndex == 0) {
                        Navigator.of(orbitContext).pop();
                        return;
                      }
                      widget.onTabSelected(orbitIndex);
                    },
                    onAddPressed: () {},
                  ),
                ),
              );
              return;
            }
            widget.onTabSelected(momentsIndex);
          },
          onAddPressed: widget.onAddPressed,
        ),
      ),
    );
  }

  void _openMomentCamera() {
    OrbitMomentCameraLauncher.openLive(context);
  }

  void _openFindFriends() {
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => const OrbitDiscoverFriendsScreen(),
      ),
    );
  }

  void _handleNotificationPressed() {
    widget.onNotificationPressed();
    // Authenticated M7 Home already opens its permission-checked inbox.
    // Do not stack the demonstration friend-request screen above it.
    if(!widget.enableDemoCircleNavigation)return;
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (requestContext) => RequestScreen.demo(
          onBack: () => Navigator.of(requestContext).pop(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        if (widget.dashboardNotice != null)
          SliverToBoxAdapter(child:_buildDashboardNotice()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(child: _buildGreeting()),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading('Quick Actions'),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        SliverToBoxAdapter(child: _buildQuickActions()),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading('Next Up', onSeeAll: widget.planUnavailable ? null : _showAllPlans),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        ..._buildUpcomingPlansSlivers(),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        if (widget.promoBanner != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeScreen._horizontalPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: PromoBannerCard(
                data: widget.promoBanner!,
                onTap: widget.onPromoPressed,
              ),
            ),
          ),
        if (widget.promoBanner != null)
          const SliverToBoxAdapter(
            child: SizedBox(height: HomeScreen._sectionGap),
          ),
        if (widget.showCircleSection) ...<Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: HomeScreen._horizontalPadding),
            sliver: SliverToBoxAdapter(
              child: _HomeSectionHeading('My Circles',onSeeAll:widget.onSeeAllCirclesPressed),
            ),
          ),
          const SliverToBoxAdapter(child:SizedBox(height:HomeScreen._sectionGap)),
          SliverToBoxAdapter(child:_buildCircleSummaries()),
          const SliverToBoxAdapter(child:SizedBox(height:HomeScreen._sectionGap)),
        ],
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading(widget.peopleSectionTitle, onSeeAll: _openFriends),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        ..._buildFavoriteSlivers(),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading(
              'Recent Moments',
              onSeeAll: _seeAllMoments,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        SliverToBoxAdapter(child: _buildMoments()),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildDashboardNotice() => Padding(
    padding: const EdgeInsets.fromLTRB(15,0,15,10),
    child: Semantics(
      liveRegion:true,
      child:Row(children:<Widget>[
        const Icon(Icons.info_outline,size:16,color:AppColors.textMuted),
        const SizedBox(width:8),
        Expanded(child:Text(widget.dashboardNotice ?? '',
          style: const TextStyle(fontFamily:AppTypography.fontFamily,
              fontSize:12,color:AppColors.textMuted))),
        if(widget.onDashboardRetry!=null) TextButton(
          onPressed:widget.onDashboardRetry,child:const Text('Retry')),
      ]),
    ),
  );

  /// The original Orbit avatar layout is an 80px circle followed by two
  /// text rows. A 112px list clips that Column on real devices, and a fixed
  /// 122px rail can clip accessibility-scaled text. Preserve every original
  /// visual dimension while letting the rail grow only when text grows.
  double _avatarRailHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final extraName = (scale.scale(12) - 12).clamp(0.0, double.infinity);
    final extraStatus = (scale.scale(11) - 11).clamp(0.0, double.infinity);
    return 122 + 1.6 * (extraName + extraStatus);
  }

  Widget _buildCircleSummaries() {
    if(widget.circleSummaries.isEmpty) {
      return const Padding(
        padding:EdgeInsets.symmetric(horizontal:HomeScreen._horizontalPadding),
        child:_HomeEmptyState('No active Circles available.'),
      );
    }
    return SizedBox(
      height: _avatarRailHeight(context),
      child:ListView.separated(
        key:HomeKeys.circlesList,
        scrollDirection:Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal:HomeScreen._horizontalPadding),
        itemCount:widget.circleSummaries.length,
        separatorBuilder:(_,__)=>const SizedBox(width:10),
        itemBuilder:(context,index){
          final circle=widget.circleSummaries[index];
          return HomeCircleSummaryTile(data:circle,
            onTap:()=>widget.onCirclePressed?.call(circle));
        },
      ),
    );
  }

  Widget _buildGreeting() {
    final trimmedName = widget.greetingName.trim();
    final displayName = trimmedName.isEmpty ? 'there' : trimmedName;
    final today=DateTime.now();
    final daypart = !widget.useLiveDate || today.hour<12 ? 'Morning'
        : today.hour<17 ? 'Afternoon' : 'Evening';
    final weekdays=const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final months=const ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    final dateLabel=widget.useLiveDate
      ? '${weekdays[today.weekday-1]}, ${months[today.month-1]} ${today.day}'
      : 'Sunday, September 22';
    final nearby = widget.nearbyFriendsCount;
    final nearbyLabel = nearby == null
        ? 'Nearby friends unavailable'
        : '$nearby ${nearby == 1 ? 'friend' : 'friends'} nearby';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
                ).createShader(bounds),
                child: const Text(
                  'ORBIT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            AppCircularIconButton(
              key: HomeKeys.findFriendsButton,
              semanticLabel: 'Find friends',
              onPressed: _openFindFriends,
              icon: Icons.person_search_outlined,
              iconSize: 20,
              iconGradient: const LinearGradient(
                colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
              ),
            ),
            const SizedBox(width: 10),
            AppCircularIconButton(
              key: HomeKeys.notificationButton,
              semanticLabel: 'Notifications',
              onPressed: _handleNotificationPressed,
              icon: Icons.notifications_none_rounded,
              iconSize: 20,
              iconGradient: const LinearGradient(
                colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppEmojiSafeText(
          'Good $daypart, $displayName \u{1F44B}',
          key: HomeKeys.greeting,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1724),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$dateLabel \u2022 $nearbyLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    if (widget.quickActions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: HomeScreen._horizontalPadding,
        ),
        child: _HomeEmptyState('No quick actions available.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeScreen._horizontalPadding,
      ),
      child: SizedBox(
        key: HomeKeys.quickActionsList,
        height: 90,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final visibleSlots = widget.quickActions.length < 4
                ? widget.quickActions.length
                : 4;
            final totalGap = gap * (visibleSlots - 1);
            final cardWidth = (constraints.maxWidth - totalGap) / visibleSlots;

            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: widget.quickActions.length,
              separatorBuilder: (context, index) => const SizedBox(width: gap),
              itemBuilder: (context, index) {
                final action = widget.quickActions[index];
                return QuickActionCard(
                  key: ValueKey<String>('quick_action_${action.id}'),
                  width: cardWidth,
                  data: action,
                  onTap: () => widget.onQuickActionPressed(action),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildUpcomingPlansSlivers() {
    if (widget.upcomingPlans.isEmpty) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeEmptyState(widget.planUnavailable
                ? 'Plans are not available yet.' : 'No upcoming plans yet.'),
          ),
        ),
      ];
    }

    final childCount = widget.upcomingPlans.length * 2 - 1;
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeScreen._horizontalPadding,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index.isOdd) {
              return const SizedBox(height: 10);
            }
            final plan = widget.upcomingPlans[index ~/ 2];
            return UpcomingPlanCard(
              key: ValueKey<String>('upcoming_plan_${plan.id}'),
              data: plan,
              onTap: () => widget.onPlanPressed(plan),
            );
          }, childCount: childCount),
        ),
      ),
    ];
  }

  List<Widget> _buildFavoriteSlivers() {
    if (_favoritePeople.isEmpty) {
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeEmptyState('No favorite people yet.'),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: SizedBox(
          height: _avatarRailHeight(context),
          child: ListView.separated(
            key: const Key('home_circle_horizontal_list'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeScreen._horizontalPadding,
            ),
            itemCount: _favoritePeople.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = _favoritePeople[index];
              return HomeCircleAvatarTile(
                key: ValueKey<String>('favorite_${person.id}'),
                data: person,
                onTap: () {
                  widget.onFavoritePersonPressed(person);
                  if(widget.enableDemoCircleNavigation)_openFavoriteCircleDetails();
                },
              );
            },
          ),
        ),
      ),
    ];
  }

  void _openFriends() {
    final handler = widget.onSeeAllFriendsPressed;
    if (handler != null) {
      handler();
      return;
    }
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (routeContext) => FriendsScreen(
          friends: _favoritePeople
              .map(
                (person) => FriendMemberData(
                  id: person.id,
                  name: person.name,
                  status: person.status,
                  imagePath: person.imagePath,
                  isFavorite: person.isFavorite,
                ),
              )
              .toList(growable: false),
          onBack: () => Navigator.of(routeContext).maybePop(),
        ),
      ),
    );
  }

  void _showAllPlans() {
    final handler = widget.onSeeAllPlansPressed;
    if (handler != null) {
      handler();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _HomeSectionHeading('Next Up'),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.upcomingPlans.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final plan = widget.upcomingPlans[index];
                    return UpcomingPlanCard(
                      data: plan,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        widget.onPlanPressed(plan);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seeAllMoments() {
    final handler = widget.onSeeAllMomentsPressed;
    if (handler != null) {
      handler();
      return;
    }
    _openMoments();
  }

  void _openFavoriteCircleDetails() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => FriendDetailsScreen.demo(
          onBack: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Widget _buildMoments() {
    if (widget.recentMoments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: HomeScreen._horizontalPadding,
        ),
        child: _HomeEmptyState('No recent moments yet.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeScreen._horizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final cardWidth = (constraints.maxWidth - 2 * gap) / 3;
          return SizedBox(
            key: HomeKeys.recentMomentsList,
            height: cardWidth * 0.78 < 82 ? 82 : cardWidth * 0.78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: widget.recentMoments.length,
              separatorBuilder: (context, index) => const SizedBox(width: gap),
              itemBuilder: (context, index) {
                final moment = widget.recentMoments[index];
                return HomeRecentMomentTile(
                  key: ValueKey<String>('moment_${moment.id}'),
                  width: cardWidth,
                  data: moment,
                  onTap: () => widget.onMomentPressed(moment),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading(this.text, {this.onSeeAll});

  final String text;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: <String>[
          'Noto Color Emoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
        ],
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F1724),
      ),
    );
    if (onSeeAll == null) return heading;
    return Row(
      children: <Widget>[
        Expanded(child: heading),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          child: InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: <Color>[AppColors.primaryStart, AppColors.primaryEnd],
                ).createShader(bounds),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: <String>[
            'Noto Color Emoji',
            'Apple Color Emoji',
            'Segoe UI Emoji',
          ],
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}
