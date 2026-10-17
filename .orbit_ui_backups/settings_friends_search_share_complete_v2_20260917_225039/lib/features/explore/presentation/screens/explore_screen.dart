import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/explore_models.dart';
import '../explore_asset_config.dart';
import '../widgets/explore_category_card.dart';
import '../widgets/explore_hero_banner.dart';
import '../widgets/explore_meetup_card.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';

abstract final class ExploreKeys {
  static const Key scroll = Key('explore_scroll');
  static const Key search = Key('explore_search');
  static const Key categoryGrid = Key('explore_category_grid');
  static const Key meetupList = Key('explore_meetup_list');
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    required this.categories,
    required this.meetups,
    this.viewState = ExploreViewState.populated,
    this.errorMessage = 'Unable to load Explore right now.',
    this.onSearchPressed,
    this.onCategoryPressed,
    this.onMeetupPressed,
    this.onSeeAllPressed,
    this.onSaveChanged,
    this.onJoinChanged,
    super.key,
  });

  factory ExploreScreen.demo() {
    return const ExploreScreen(
      categories: <ExploreCategoryData>[
        ExploreCategoryData(
          id: 'nearby',
          title: 'Nearby',
          count: 12,
          iconAsset: ExploreAssetConfig.nearbyIcon,
        ),
        ExploreCategoryData(
          id: 'travelers',
          title: 'Travelers',
          count: 24,
          iconAsset: ExploreAssetConfig.travelersIcon,
        ),
        ExploreCategoryData(
          id: 'hikers',
          title: 'Hikers',
          count: 18,
          iconAsset: ExploreAssetConfig.hikersIcon,
        ),
        ExploreCategoryData(
          id: 'foodies',
          title: 'Foodies',
          count: 16,
          iconAsset: ExploreAssetConfig.foodiesIcon,
        ),
        ExploreCategoryData(
          id: 'gamers',
          title: 'Gamers',
          count: 22,
          iconAsset: ExploreAssetConfig.gamersIcon,
        ),
        ExploreCategoryData(
          id: 'entrepreneurs',
          title: 'Entrepreneurs',
          count: 15,
          iconAsset: ExploreAssetConfig.entrepreneursIcon,
        ),
      ],
      meetups: <ExploreMeetupData>[
        ExploreMeetupData(
          id: 'sunset-hike',
          title: 'Sunset Hike',
          image: ExploreAssetConfig.meetupOne,
          dateTimeLabel: 'Today · 6:00 PM',
          secondaryLabel: '3.2 mi · Easy',
          attendeeAvatars: <String?>[
            ExploreAssetConfig.avatarOne,
            ExploreAssetConfig.avatarTwo,
            ExploreAssetConfig.avatarThree,
          ],
          attendeeCount: 8,
        ),
        ExploreMeetupData(
          id: 'coffee-connect',
          title: 'Coffee & Connect',
          image: ExploreAssetConfig.meetupTwo,
          dateTimeLabel: 'Tomorrow · 10:00 AM',
          secondaryLabel: '1.1 mi · Downtown',
          attendeeAvatars: <String?>[
            ExploreAssetConfig.avatarTwo,
            ExploreAssetConfig.avatarThree,
            ExploreAssetConfig.avatarOne,
          ],
          attendeeCount: 5,
        ),
      ],
    );
  }

  final List<ExploreCategoryData> categories;
  final List<ExploreMeetupData> meetups;
  final ExploreViewState viewState;
  final String errorMessage;
  final VoidCallback? onSearchPressed;
  final ValueChanged<ExploreCategoryData>? onCategoryPressed;
  final ValueChanged<ExploreMeetupData>? onMeetupPressed;
  final VoidCallback? onSeeAllPressed;
  final void Function(ExploreMeetupData meetup, bool isSaved)? onSaveChanged;
  final void Function(ExploreMeetupData meetup, bool isJoined)? onJoinChanged;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final OrbitSearchController _searchController = OrbitSearchController();
  String _searchQuery = '';

  static const double _horizontalPadding = 20;
  final Map<String, bool> _saved = <String, bool>{};
  final Map<String, bool> _joined = <String, bool>{};

  bool _isSaved(ExploreMeetupData meetup) =>
      _saved[meetup.id] ?? meetup.isSaved;
  bool _isJoined(ExploreMeetupData meetup) =>
      _joined[meetup.id] ?? meetup.isJoined;
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (widget.viewState) {
      case ExploreViewState.loading:
        return const _ExploreStatusState(
          icon: Icons.explore_outlined,
          title: 'Loading Explore…',
          showProgress: true,
        );
      case ExploreViewState.error:
        return _ExploreStatusState(
          icon: Icons.error_outline_rounded,
          title: widget.errorMessage,
        );
      case ExploreViewState.empty:
        return const _ExploreStatusState(
          icon: Icons.event_busy_outlined,
          title: 'No Explore results yet.',
        );
      case ExploreViewState.populated:
        return _buildPopulated();
    }
  }

  List<ExploreCategoryData> get _visibleCategories {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.categories;

    return widget.categories
        .where((item) {
          return item.title.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<ExploreMeetupData> get _visibleMeetups {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.meetups;

    return widget.meetups
        .where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.dateTimeLabel.toLowerCase().contains(query) ||
              item.secondaryLabel.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Widget _buildPopulated() {
    return CustomScrollView(
      key: ExploreKeys.scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          sliver: SliverToBoxAdapter(child: _buildHeader()),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          sliver: SliverToBoxAdapter(
            child: ExploreHeroBanner(imagePath: ExploreAssetConfig.heroBanner),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        if (_visibleCategories.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverToBoxAdapter(
              child: _InlineEmptyState('No categories available.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverGrid(
              key: ExploreKeys.categoryGrid,
              delegate: SliverChildBuilderDelegate((context, index) {
                final data = _visibleCategories[index];
                return ExploreCategoryCard(
                  key: ValueKey<String>('explore_category_${data.id}'),
                  data: data,
                  onTap: () => widget.onCategoryPressed?.call(data),
                );
              }, childCount: _visibleCategories.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 90,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          sliver: SliverToBoxAdapter(child: _buildMeetupsHeading()),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        if (_visibleMeetups.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverToBoxAdapter(
              child: _InlineEmptyState('No upcoming meetups yet.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverList(
              key: ExploreKeys.meetupList,
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index.isOdd) return const SizedBox(height: 10);
                final meetup = _visibleMeetups[index ~/ 2];
                return ExploreMeetupCard(
                  key: ValueKey<String>('explore_meetup_${meetup.id}'),
                  data: meetup,
                  isSaved: _isSaved(meetup),
                  isJoined: _isJoined(meetup),
                  onTap: () => widget.onMeetupPressed?.call(meetup),
                  onSave: () => _toggleSaved(meetup),
                  onJoin: () => _toggleJoined(meetup),
                );
              }, childCount: _visibleMeetups.length * 2 - 1),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _buildHeader() {
    return OrbitSearchableHeader(
      title: 'Explore',
      placeholder: 'Search people, categories or meetups',
      controller: _searchController,
      showBack: false,
      onSearchOpened: widget.onSearchPressed,
      onQueryChanged: (value) {
        setState(() => _searchQuery = value);
      },
      searchButtonKey: ExploreKeys.search,
    );
  }

  Widget _buildMeetupsHeading() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Expanded(
          child: Text(
            'Upcoming Meetups',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontFamilyFallback: <String>[AppTypography.fontFamily],
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: widget.onSeeAllPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
              ).createShader(bounds),
              child: const Text(
                'See all',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontFamilyFallback: <String>[AppTypography.fontFamily],
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleSaved(ExploreMeetupData meetup) {
    final next = !_isSaved(meetup);
    setState(() => _saved[meetup.id] = next);
    widget.onSaveChanged?.call(meetup, next);
  }

  void _toggleJoined(ExploreMeetupData meetup) {
    final next = !_isJoined(meetup);
    setState(() => _joined[meetup.id] = next);
    widget.onJoinChanged?.call(meetup, next);
  }
}

class _ExploreStatusState extends StatelessWidget {
  const _ExploreStatusState({
    required this.icon,
    required this.title,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showProgress)
              const CircularProgressIndicator(color: Color(0xFF7C3AED))
            else
              Icon(icon, size: 40, color: const Color(0xFF7C3AED)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E9196),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          color: Color(0xFF8E9196),
        ),
      ),
    );
  }
}
