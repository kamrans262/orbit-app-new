import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/promo_banner_card.dart';
import '../../../profile/presentation/navigation/profile_navigation.dart';
import '../../domain/models/moments_models.dart';
import 'moment_camera_screen.dart';
import '../widgets/moment_image_card.dart';
import '../widgets/moment_story_avatar.dart';
import '../widgets/moment_text_card.dart';
import '../widgets/moment_video_placeholder_card.dart';

abstract final class MomentsKeys {
  static const header = Key('moments_header');
  static const storiesList = Key('moments_stories_list');
  static const feed = Key('moments_feed');
  static const searchButton = Key('moments_search_button');
  static const filterButton = Key('moments_filter_button');
  static const messagesButton = Key('moments_messages_button');
  static const bottomNavigation = Key('moments_bottom_navigation');
  static const loadingState = Key('moments_loading_state');
  static const emptyState = Key('moments_empty_state');
  static const errorState = Key('moments_error_state');

  static Key story(String id) => Key('moment_story_$id');
  static Key feedItem(String id) => Key('moment_feed_$id');
}

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({
    required this.stories,
    required this.feedItems,
    required this.onSearchPressed,
    required this.onFilterPressed,
    required this.onMessagesPressed,
    required this.onStoryPressed,
    required this.onLikeChanged,
    required this.onCommentPressed,
    required this.onBookmarkChanged,
    required this.onSharePressed,
    required this.onTextMenuPressed,
    required this.onFeedItemPressed,
    required this.onTabSelected,
    required this.onAddPressed,
    this.viewState = MomentsViewState.populated,
    this.errorMessage = 'Something went wrong. Please try again.',
    this.cameraBuilder,
    super.key,
  });

  factory MomentsScreen.demo({
    ValueChanged<int>? onTabSelected,
    VoidCallback? onAddPressed,
    WidgetBuilder? cameraBuilder,
  }) {
    const stories = <MomentStoryData>[
      MomentStoryData(id: 'you', name: 'You', isAddStory: true),
      MomentStoryData(id: 'emma', name: 'Emma', imagePath: 'assets/Emma.png'),
      MomentStoryData(id: 'mike', name: 'Mike', imagePath: 'assets/Mike.png'),
      MomentStoryData(
        id: 'sophia',
        name: 'Sophia',
        imagePath: 'assets/Sophia.png',
      ),
      MomentStoryData(id: 'daisy', name: 'Daisy', imagePath: 'assets/Emma.png'),
      MomentStoryData(id: 'finn', name: 'Finn', imagePath: 'assets/Mike.png'),
      MomentStoryData(
        id: 'suzie',
        name: 'Suzie',
        imagePath: 'assets/Sophia.png',
      ),
    ];

    const emma = MomentAuthorData(
      id: 'emma',
      name: 'Emma',
      imagePath: 'assets/Emma.png',
    );
    const mike = MomentAuthorData(
      id: 'mike',
      name: 'Mike',
      imagePath: 'assets/Mike.png',
    );

    return MomentsScreen(
      stories: stories,
      feedItems: const <MomentFeedItem>[
        MomentImageFeedItem(
          id: 'sunset-walk',
          author: emma,
          timeLabel: '8m ago',
          imagePath: 'assets/moment_card.jpg',
          title: 'Sunset walk ðŸŒ…',
          location: 'Santa Monica Beach',
          likeCount: 128,
          commentCount: 14,
        ),
        MomentPromoFeedItem(
          id: 'ride-together',
          backgroundImagePath: 'assets/banner.png',
          logoImagePath: 'assets/bannerlogo.png',
          title: 'Get there together',
          subtitle: 'Ride with friends',
        ),
        MomentTextFeedItem(
          id: 'mike-run',
          author: mike,
          timeLabel: '15m ago',
          text: 'Just finished a 10k run! ðŸƒ Feeling amazing. Anyone down for a hike this weekend?',
        ),
      ],
      onSearchPressed: () {},
      onFilterPressed: () {},
      onMessagesPressed: () {},
      onStoryPressed: (story) {},
      onLikeChanged: (item, isLiked) {},
      onCommentPressed: (item) {},
      onBookmarkChanged: (item, isBookmarked) {},
      onSharePressed: (item) {},
      onTextMenuPressed: (item) {},
      onFeedItemPressed: (item) {},
      onTabSelected: onTabSelected ?? (index) {},
      onAddPressed: onAddPressed ?? () {},
      cameraBuilder: cameraBuilder,
    );
  }

  final List<MomentStoryData> stories;
  final List<MomentFeedItem> feedItems;
  final VoidCallback onSearchPressed;
  final VoidCallback onFilterPressed;
  final VoidCallback onMessagesPressed;
  final ValueChanged<MomentStoryData> onStoryPressed;
  final void Function(MomentImageFeedItem item, bool isLiked) onLikeChanged;
  final ValueChanged<MomentImageFeedItem> onCommentPressed;
  final void Function(MomentImageFeedItem item, bool isBookmarked)
  onBookmarkChanged;
  final ValueChanged<MomentImageFeedItem> onSharePressed;
  final ValueChanged<MomentTextFeedItem> onTextMenuPressed;
  final ValueChanged<MomentFeedItem> onFeedItemPressed;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final MomentsViewState viewState;
  final String errorMessage;
  final WidgetBuilder? cameraBuilder;

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  static const double _horizontalPadding = 20;
  static const double _sectionGap = 20;

  final Map<String, bool> _likedById = <String, bool>{};
  final Map<String, bool> _bookmarkedById = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _seedEngagementState();
  }

  @override
  void didUpdateWidget(covariant MomentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feedItems, widget.feedItems)) {
      _seedEngagementState();
    }
  }

  void _seedEngagementState() {
    _likedById.clear();
    _bookmarkedById.clear();
    for (final item in widget.feedItems) {
      if (item is MomentImageFeedItem) {
        _likedById[item.id] = item.isLiked;
        _bookmarkedById[item.id] = item.isBookmarked;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNavigationBar(
          key: MomentsKeys.bottomNavigation,
          selectedIndex: 2,
          onTabSelected: _handleBottomTabSelected,
          onAddPressed: _openCamera,
        ),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: MomentsKeys.feed,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: <Widget>[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
              ..._buildContentSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBottomTabSelected(int index) {
    if (index == 2) {
      return;
    }
    if (index == 3) {
      unawaited(_openProfile());
      return;
    }
    widget.onTabSelected(index);
  }

  Future<void> _openProfile() async {
    final targetIndex = await openProfileScreen(
      context: context,
      onAddPressed: widget.onAddPressed,
    );
    if (!mounted || targetIndex == null) {
      return;
    }
    _handleBottomTabSelected(targetIndex);
  }

  void _openCamera() {
    widget.onAddPressed();
    final cameraBuilder = widget.cameraBuilder;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: cameraBuilder ?? (_) => const MomentCameraScreen(),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      key: MomentsKeys.header,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Expanded(
          child: Text(
            'Moments',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F1724),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AppCircularIconButton(
          key: MomentsKeys.searchButton,
          semanticLabel: 'Search moments',
          onPressed: widget.onSearchPressed,
          icon: Icons.search_rounded,
          iconSize: 20,
          iconColor: const Color(0xFF7C3AED),
        ),
        const SizedBox(width: 5),
        AppCircularIconButton(
          key: MomentsKeys.filterButton,
          semanticLabel: 'Filter moments',
          onPressed: widget.onFilterPressed,
          icon: Icons.tune_rounded,
          iconSize: 20,
          iconColor: const Color(0xFF7C3AED),
        ),
        const SizedBox(width: 5),
        AppCircularIconButton(
          key: MomentsKeys.messagesButton,
          semanticLabel: 'Messages',
          onPressed: widget.onMessagesPressed,
          icon: Icons.chat_bubble_outline_rounded,
          iconSize: 20,
          iconColor: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  List<Widget> _buildContentSlivers() {
    switch (widget.viewState) {
      case MomentsViewState.loading:
        return const <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _MomentsLoadingState(),
          ),
        ];
      case MomentsViewState.error:
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _MomentsMessageState(
              key: MomentsKeys.errorState,
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load moments',
              message: widget.errorMessage,
            ),
          ),
        ];
      case MomentsViewState.empty:
        return const <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _MomentsMessageState(
              key: MomentsKeys.emptyState,
              icon: Icons.photo_library_outlined,
              title: 'No moments yet',
              message: 'New moments from your circle will appear here.',
            ),
          ),
        ];
      case MomentsViewState.populated:
        return _buildPopulatedSlivers();
    }
  }

  List<Widget> _buildPopulatedSlivers() {
    final slivers = <Widget>[];

    if (widget.stories.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          sliver: SliverToBoxAdapter(child: _buildStories()),
        ),
      );
      slivers.add(
        const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
      );
    }

    if (widget.feedItems.isEmpty) {
      slivers.add(
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _MomentsMessageState(
            key: MomentsKeys.emptyState,
            icon: Icons.photo_library_outlined,
            title: 'No moments yet',
            message: 'New moments from your circle will appear here.',
          ),
        ),
      );
      return slivers;
    }

    final childCount = widget.feedItems.length * 2 - 1;
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index.isOdd) {
              return const SizedBox(height: _sectionGap);
            }
            final item = widget.feedItems[index ~/ 2];
            return KeyedSubtree(
              key: MomentsKeys.feedItem(item.id),
              child: _buildFeedItem(item),
            );
          }, childCount: childCount),
        ),
      ),
    );
    return slivers;
  }

  Widget _buildStories() {
    return SizedBox(
      key: MomentsKeys.storiesList,
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: widget.stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          return MomentStoryAvatar(
            key: MomentsKeys.story(story.id),
            data: story,
            onTap: story.isAddStory
                ? _openCamera
                : () => widget.onStoryPressed(story),
          );
        },
      ),
    );
  }

  Widget _buildFeedItem(MomentFeedItem item) {
    switch (item.type) {
      case MomentFeedItemType.imagePost:
        final imageItem = item as MomentImageFeedItem;
        return MomentImageCard(
          data: imageItem,
          isLiked: _likedById[imageItem.id] ?? imageItem.isLiked,
          isBookmarked: _bookmarkedById[imageItem.id] ?? imageItem.isBookmarked,
          onLikePressed: () => _toggleLike(imageItem),
          onCommentPressed: () => widget.onCommentPressed(imageItem),
          onBookmarkPressed: () => _toggleBookmark(imageItem),
          onSharePressed: () => widget.onSharePressed(imageItem),
        );
      case MomentFeedItemType.promo:
        final promo = item as MomentPromoFeedItem;
        return PromoBannerCard(
          data: PromoBannerData(
            id: promo.id,
            backgroundImagePath: promo.backgroundImagePath,
            logoImagePath: promo.logoImagePath,
            title: promo.title,
            subtitle: promo.subtitle,
          ),
          onTap: () => widget.onFeedItemPressed(promo),
        );
      case MomentFeedItemType.textPost:
        final textItem = item as MomentTextFeedItem;
        return MomentTextCard(
          data: textItem,
          onMenuPressed: () => widget.onTextMenuPressed(textItem),
        );
      case MomentFeedItemType.futureVideoPost:
        final videoItem = item as MomentFutureVideoFeedItem;
        return MomentVideoPlaceholderCard(
          data: videoItem,
          onTap: () => widget.onFeedItemPressed(videoItem),
        );
    }
  }

  void _toggleLike(MomentImageFeedItem item) {
    final nextValue = !(_likedById[item.id] ?? item.isLiked);
    setState(() => _likedById[item.id] = nextValue);
    widget.onLikeChanged(item, nextValue);
  }

  void _toggleBookmark(MomentImageFeedItem item) {
    final nextValue = !(_bookmarkedById[item.id] ?? item.isBookmarked);
    setState(() => _bookmarkedById[item.id] = nextValue);
    widget.onBookmarkChanged(item, nextValue);
  }
}

class _MomentsLoadingState extends StatelessWidget {
  const _MomentsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: MomentsKeys.loadingState,
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

class _MomentsMessageState extends StatelessWidget {
  const _MomentsMessageState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 34, color: const Color(0xFF7C3AED)),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1724),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8A85A8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
