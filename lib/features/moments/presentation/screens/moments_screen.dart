import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/promo_banner_card.dart';
import '../../../profile/presentation/navigation/profile_navigation.dart';
import '../../domain/models/moments_models.dart';
import '../../../profile/presentation/screens/report_user_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import 'moment_camera_screen.dart';
import '../orbit_camera_permission_memory.dart';
import '../widgets/moment_image_card.dart';
import '../../../media/data/orbit_moment_media_stager.dart';
import '../widgets/moment_story_avatar.dart';
import '../widgets/moment_text_card.dart';
import '../widgets/moment_video_placeholder_card.dart';

import '../widgets/no_moments_popup.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../../../core/services/orbit_share_service.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';

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
    this.privateMode=false,
    this.privateReadOnly=false,
    this.privateFiltering=false,
    this.privateBookmarking=false,
    this.privateSharing=false,
    this.onRefresh,
    this.pendingCard,
    this.onLoadMore,
    this.hasMore=false,
    this.loadingMore=false,
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
          title: 'Sunset walk \u{1F305}',
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
          text: 'Just finished a 10k run! \u{1F3C3} Feeling amazing. Anyone down for a hike this weekend?',
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
  final bool privateMode;
  final bool privateReadOnly;
  final bool privateFiltering;
  final bool privateBookmarking;
  final bool privateSharing;
  final Future<void> Function()? onRefresh;
  final Widget? pendingCard;
  final VoidCallback? onLoadMore;
  final bool hasMore,loadingMore;

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  final OrbitSearchController _searchController = OrbitSearchController();
  String _searchQuery = '';
  bool _savedOnly=false;

  static const double _horizontalPadding = 20;
  static const double _sectionGap = 20;

  final Map<String, bool> _likedById = <String, bool>{};
  final Map<String, bool> _bookmarkedById = <String, bool>{};

  bool _noMomentsPopupScheduled = false;
  bool _noMomentsPopupHandled = false;

  @override
  void initState() {
    super.initState();
    _seedEngagementState();
    _scheduleNoMomentsPopupIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MomentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feedItems, widget.feedItems)) {
      _seedEngagementState();
    }
    _scheduleNoMomentsPopupIfNeeded();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          child: RefreshIndicator(
          onRefresh:widget.onRefresh ?? () async {},
          color:AppColors.primaryEnd,
          child: CustomScrollView(
            key: MomentsKeys.feed,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics:const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
              if(widget.pendingCard!=null)SliverPadding(
                padding:const EdgeInsets.fromLTRB(20,0,20,16),
                sliver:SliverToBoxAdapter(child:widget.pendingCard!),
              ),
              ..._buildContentSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
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

  bool get _shouldShowNoMomentsPopup =>
      widget.viewState == MomentsViewState.empty ||
      (widget.viewState == MomentsViewState.populated &&
          widget.feedItems.isEmpty);

  void _scheduleNoMomentsPopupIfNeeded() {
    if (!_shouldShowNoMomentsPopup ||
        _noMomentsPopupHandled ||
        _noMomentsPopupScheduled) {
      return;
    }

    _noMomentsPopupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _noMomentsPopupScheduled = false;
      if (!mounted || !_shouldShowNoMomentsPopup || _noMomentsPopupHandled) {
        return;
      }

      _noMomentsPopupHandled = true;
      await showNoMomentsPopup(
        context,
        onCreateMoment: _openCameraFromNoMomentsPopup,
      );
    });
  }

  void _openCameraFromNoMomentsPopup() {
    if (!mounted) {
      return;
    }
    _openCamera();
  }

  void _openCamera() {
    unawaited(_openCameraRespectingStoredPermission());
  }

  Future<void> _openCameraRespectingStoredPermission() async {
    final alreadyConfirmed =
        await OrbitCameraPermissionMemory.hasConfirmedCameraAccess();

    if (!mounted) {
      return;
    }

    if (alreadyConfirmed) {
      _openCameraAfterPermission();
      return;
    }

    await showCameraPermissionPopup(
      context,
      onAllow: _openCameraAfterPermission,
      onNotNow: () {},
    );
  }

  void _openCameraAfterPermission() {
    widget.onAddPressed();
    final cameraBuilder = widget.cameraBuilder;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: cameraBuilder ?? (_) => MomentCameraScreen(
          privateSaver: (bytes, progress) async {
            final saved = await OrbitMomentMediaStager()
                .stagePhoto(bytes, onProgress: progress);
            if (!saved.thumbnailVerified || !saved.privateGrantConfirmed) {
              throw StateError('Private encrypted storage not confirmed.');
            }
          },
        ),
      ),
    );
  }

  void _openMessages() {
    widget.onMessagesPressed();
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(builder: (_) => MessagesScreen.demo()),
    );
  }

  Widget _buildHeader() {
    ThemeData noFlashTheme(BuildContext context) {
      return Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      );
    }

    return OrbitSearchableHeader(
      title: 'Moments',
      placeholder: 'Search moments',
      controller: _searchController,
      showBack: false,
      onSearchOpened: widget.onSearchPressed,
      onQueryChanged: (value) {
        setState(() => _searchQuery = value);
      },
      searchButtonKey: MomentsKeys.searchButton,
      trailingActions: <Widget>[
        if(widget.privateMode && widget.privateBookmarking)
          AppCircularIconButton(
            semanticLabel:_savedOnly?'Show all Moments':'Show saved Moments',
            onPressed:()=>setState(()=>_savedOnly=!_savedOnly),
            icon:_savedOnly?Icons.bookmark_rounded:Icons.bookmarks_outlined,
            iconSize:20,size:40),
        if(!widget.privateMode || widget.privateFiltering)Theme(
          data: noFlashTheme(context),
          child: AppCircularIconButton(
            key: MomentsKeys.filterButton,
            semanticLabel: 'Filter moments',
            onPressed: widget.onFilterPressed,
            icon: Icons.tune_rounded,
            iconSize: 20,
            iconColor: const Color(0xFF7C3AED),
            size: 40,
          ),
        ),
        if(!widget.privateMode)Theme(
          data: noFlashTheme(context),
          child: AppCircularIconButton(
            key: MomentsKeys.messagesButton,
            semanticLabel: 'Messages',
            onPressed: _openMessages,
            icon: Icons.chat_bubble_outline_rounded,
            iconSize: 20,
            iconColor: const Color(0xFF7C3AED),
            size: 40,
          ),
        ),
      ],
    );
  }

  List<MomentStoryData> get _visibleStories {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.stories;

    return widget.stories
        .where((story) {
          if (story.isAddStory) return true;
          return story.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<MomentFeedItem> get _visibleFeedItems {
    final query = _searchQuery.trim().toLowerCase();
    final visible=widget.privateBookmarking && _savedOnly
        ? widget.feedItems.where((item)=>item is MomentImageFeedItem &&
            (_bookmarkedById[item.id]??item.isBookmarked)).toList()
        : widget.feedItems;
    if (query.isEmpty) return visible;

    return visible
        .where((item) {
          if (item is MomentImageFeedItem) {
            return item.author.name.toLowerCase().contains(query) ||
                item.title.toLowerCase().contains(query) ||
                item.location.toLowerCase().contains(query);
          }
          if (item is MomentTextFeedItem) {
            return item.author.name.toLowerCase().contains(query) ||
                item.text.toLowerCase().contains(query);
          }
          if (item is MomentPromoFeedItem) {
            return item.title.toLowerCase().contains(query) ||
                item.subtitle.toLowerCase().contains(query);
          }
          if (item is MomentFutureVideoFeedItem) {
            return item.author.name.toLowerCase().contains(query) ||
                item.caption.toLowerCase().contains(query);
          }
          return false;
        })
        .toList(growable: false);
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
            child: Column(mainAxisAlignment:MainAxisAlignment.center,
              children:[
                _MomentsMessageState(
                  key: MomentsKeys.errorState,
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load moments',
                  message: widget.errorMessage,
                ),
                if(widget.onRefresh!=null)TextButton(
                  onPressed:()=>unawaited(widget.onRefresh!()),
                  child:const Text('Try again'),
                ),
              ],
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
    final stories = _visibleStories;
    final feedItems = _visibleFeedItems;

    final slivers = <Widget>[];

    if (stories.isNotEmpty) {
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

    if (feedItems.isEmpty) {
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

    final childCount = feedItems.length * 2 - 1;
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index.isOdd) {
              return const SizedBox(height: _sectionGap);
            }
            final item = feedItems[index ~/ 2];
            return KeyedSubtree(
              key: MomentsKeys.feedItem(item.id),
              child: _buildFeedItem(item),
            );
          }, childCount: childCount),
        ),
      ),
    );
    if(widget.hasMore && widget.onLoadMore!=null){
      slivers.add(SliverPadding(
        padding:const EdgeInsets.fromLTRB(20,16,20,30),
        sliver:SliverToBoxAdapter(child:OutlinedButton(
          key:const Key('moments_load_more'),
          onPressed:widget.loadingMore?null:widget.onLoadMore,
          child:Text(widget.loadingMore?'Loading more…':'Load more Moments'),
        )),
      ));
    }
    return slivers;
  }

  Widget _buildStories() {
    final stories = _visibleStories;

    return SizedBox(
      key: MomentsKeys.storiesList,
      height: stories.any((entry)=>entry.ageLabel!=null)?96:76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final story = stories[index];
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
          privateMode:widget.privateMode,
          privateBookmarking:widget.privateBookmarking,
          privateSharing:widget.privateSharing,
          onViewPressed:()=>widget.onFeedItemPressed(imageItem),
          isLiked: _likedById[imageItem.id] ?? imageItem.isLiked,
          isBookmarked: _bookmarkedById[imageItem.id] ?? imageItem.isBookmarked,
          onLikePressed: () => _toggleLike(imageItem),
          onCommentPressed: () => widget.onCommentPressed(imageItem),
          onBookmarkPressed: () => _toggleBookmark(imageItem),
          onSharePressed: () => _shareMoment(imageItem),
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
          onMenuPressed: () => _handleTextMomentMenu(textItem),
        );
      case MomentFeedItemType.futureVideoPost:
        final videoItem = item as MomentFutureVideoFeedItem;
        return MomentVideoPlaceholderCard(
          data: videoItem,
          onTap: () => widget.onFeedItemPressed(videoItem),
        );
    }
  }

  Future<void> _handleTextMomentMenu(MomentTextFeedItem item) async {
    widget.onTextMenuPressed(item);
    if (!mounted) {
      return;
    }

    final shouldReport = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Moment options',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Report User',
                child: GestureDetector(
                  key: const Key('moments_report_user_action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(sheetContext).pop(true),
                  child: const SizedBox(
                    height: 52,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.flag_outlined,
                          size: 22,
                          color: Color(0xFFF44336),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Report User',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F1724),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldReport != true || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      AppFadeSlidePageRoute<void>(
        builder: (_) => ReportUserScreen.forUser(
          userId: item.author.id,
          displayName: item.author.name,
        ),
      ),
    );
  }

  void _shareMoment(MomentImageFeedItem item) {
    widget.onSharePressed(item);
    if(widget.privateMode)return;
    unawaited(
      OrbitShareService.shareMoment(
        authorName: item.author.name,
        text: item.title,
        location: item.location,
      ),
    );
  }

  void _toggleLike(MomentImageFeedItem item) {
    if(widget.privateReadOnly)return;
    final nextValue = !(_likedById[item.id] ?? item.isLiked);
    setState(() => _likedById[item.id] = nextValue);
    widget.onLikeChanged(item, nextValue);
  }

  void _toggleBookmark(MomentImageFeedItem item) {
    if(widget.privateReadOnly)return;
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
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
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
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
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
