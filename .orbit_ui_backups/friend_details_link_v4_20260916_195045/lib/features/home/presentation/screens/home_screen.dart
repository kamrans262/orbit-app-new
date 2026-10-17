import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../orbit/presentation/screens/orbit_screen.dart';
import '../../../moments/presentation/screens/moments_screen.dart';
import '../../domain/models/home_models.dart';
import '../widgets/favorite_person_tile.dart';
import '../widgets/moment_card.dart';
import '../widgets/promo_banner_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/upcoming_plan_card.dart';

abstract final class HomeKeys {
  static const greeting = Key('home_greeting');
  static const notificationButton = Key('home_notification_button');
  static const quickActionsList = Key('home_quick_actions_list');
  static const recentMomentsList = Key('home_recent_moments_list');
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
    this.selectedBottomIndex = 0,
    this.isLoading = false,
    super.key,
  });

  factory HomeScreen.demo({
    ValueChanged<int>? onTabSelected,
    VoidCallback? onAddPressed,
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
          schedule: 'Today · 7:00Pm',
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
      recentMoments: const <MomentData>[
        MomentData(
          id: 'm1',
          name: 'Finn',
          timeLabel: '1h ago',
          imagePath: 'assets/m1.jpg',
        ),
        MomentData(
          id: 'm2',
          name: 'Emma',
          timeLabel: '2h ago',
          imagePath: 'assets/m2.jpg',
        ),
        MomentData(
          id: 'm3',
          name: 'Mike',
          timeLabel: '3h ago',
          imagePath: 'assets/m3.jpg',
        ),
        MomentData(
          id: 'm4',
          name: 'Sophia',
          timeLabel: '5h ago',
          imagePath: 'assets/m4.jpg',
        ),
      ],
      onNotificationPressed: () {},
      onQuickActionPressed: (action) {},
      onPlanPressed: (plan) {},
      onPromoPressed: () {},
      onFavoritePersonPressed: (person) {},
      onFavoriteToggle: (person) {},
      onMomentPressed: (moment) {},
      onTabSelected: onTabSelected ?? (index) {},
      onAddPressed: onAddPressed ?? () {},
    );
  }

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
        onAddPressed: widget.onAddPressed,
      ),
      body: SafeArea(
        bottom: false,
        child: widget.isLoading ? const _HomeLoadingState() : _buildContent(),
      ),
    );
  }

  void _handleBottomTabSelected(int index) {
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

  void _openOrbit() {
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
          onAddPressed: widget.onAddPressed,
        ),
      ),
    );
  }

  void _openMoments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => MomentsScreen.demo(
          onTabSelected: (momentsIndex) {
            if (momentsIndex == 0) {
              Navigator.of(routeContext).pop();
              return;
            }
            if (momentsIndex == 1) {
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
                    onAddPressed: widget.onAddPressed,
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

  Widget _buildContent() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
        const SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading('Upcoming Plans'),
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
        const SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading('Favorite Circle'),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        ..._buildFavoriteSlivers(),
        const SliverToBoxAdapter(
          child: SizedBox(height: HomeScreen._sectionGap),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeSectionHeading('Recent Moments'),
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

  Widget _buildGreeting() {
    final trimmedName = widget.greetingName.trim();
    final displayName = trimmedName.isEmpty ? 'there' : trimmedName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            'Good Morning, $displayName 👋',
            key: HomeKeys.greeting,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F1724),
            ),
          ),
        ),
        const SizedBox(width: 12),
        AppCircularIconButton(
          key: HomeKeys.notificationButton,
          semanticLabel: 'Notifications',
          onPressed: widget.onNotificationPressed,
          icon: Icons.notifications_none_rounded,
          iconSize: 20,
          iconGradient: const LinearGradient(
            colors: <Color>[Color(0xFFED65C9), Color(0xFF7C3AED)],
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
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: HomeScreen._horizontalPadding,
          ),
          sliver: SliverToBoxAdapter(
            child: _HomeEmptyState('No upcoming plans yet.'),
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

    final childCount = _favoritePeople.length * 2 - 1;
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
            final person = _favoritePeople[index ~/ 2];
            return FavoritePersonTile(
              key: ValueKey<String>('favorite_${person.id}'),
              data: person,
              onTap: () => widget.onFavoritePersonPressed(person),
              onFavoritePressed: () => _toggleFavorite(index ~/ 2),
            );
          }, childCount: childCount),
        ),
      ),
    ];
  }

  void _toggleFavorite(int index) {
    final current = _favoritePeople[index];
    final updated = current.copyWith(isFavorite: !current.isFavorite);
    setState(() {
      _favoritePeople[index] = updated;
    });
    widget.onFavoriteToggle(updated);
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

    return SizedBox(
      key: HomeKeys.recentMomentsList,
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: HomeScreen._horizontalPadding,
        ),
        itemCount: widget.recentMoments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final moment = widget.recentMoments[index];
          return MomentCard(
            key: ValueKey<String>('moment_${moment.id}'),
            data: moment,
            onTap: () => widget.onMomentPressed(moment),
          );
        },
      ),
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F1724),
      ),
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
