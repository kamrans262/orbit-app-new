import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../domain/models/profile_models.dart';
import '../widgets/profile_moment_tile.dart';
import '../widgets/profile_overview_sections.dart';
import '../widgets/profile_summary_header.dart';
import 'profile_moment_detail_screen.dart';
import 'profile_settings_screen.dart';

abstract final class ProfileKeys {
  static const scrollView = Key('profile_scroll_view');
  static const avatar = Key('profile_avatar');
  static const settingsButton = Key('profile_settings_button');
  static const stats = Key('profile_stats');
  static const gallery = Key('profile_gallery');
  static const bottomNavigation = Key('profile_bottom_navigation');
  static const loadingState = Key('profile_loading_state');
  static const emptyState = Key('profile_empty_state');
  static const errorState = Key('profile_error_state');
  static const gradientBackground = Key('profile_gradient_background');
  static const overviewTab = Key('profile_overview_tab');
  static const placesTab = Key('profile_places_tab');
  static const momentsTab = Key('profile_moments_tab');

  static Key moment(String id) => Key('profile_moment_$id');
}

/// Profile in the current Orbit design system. All demonstration map, place and
/// highlight content is local UI data, not a claim that location is being read.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.profile,
    required this.onTabSelected,
    required this.onAddPressed,
    required this.onRetry,
    this.viewState = ProfileViewState.populated,
    this.errorMessage = 'Something went wrong. Please try again.',
    this.settingsBuilder,
    this.onSettingsClosed,
    this.momentDetailBuilder,
    this.onMomentPressed,
    super.key,
  });

  factory ProfileScreen.demo({
    ValueChanged<int>? onTabSelected,
    VoidCallback? onAddPressed,
  }) {
    return ProfileScreen(
      profile: const ProfileData(
        id: 'emma',
        name: 'Emma ⭐',
        bio: 'Good vibes only',
        imagePath: 'assets/Emma.png',
        circleCount: 10,
        friendCount: 24,
        momentCount: 120,
        moments: <ProfileMomentData>[
          ProfileMomentData(
            id: 'gallery-1',
            imagePath: 'assets/gallery1.jpg',
            likeCount: 34,
            aspectRatio: 0.86,
          ),
          ProfileMomentData(
            id: 'gallery-4',
            imagePath: 'assets/gallery4.jpg',
            likeCount: 63,
            aspectRatio: 1.28,
          ),
          ProfileMomentData(
            id: 'gallery-more',
            imagePath: 'assets/gallery2.jpg',
            likeCount: 92,
            remainingCount: 202,
            aspectRatio: 0.84,
          ),
          ProfileMomentData(
            id: 'gallery-3',
            imagePath: 'assets/gallery3.jpg',
            likeCount: 57,
            aspectRatio: 1.55,
          ),
          ProfileMomentData(
            id: 'gallery-5',
            imagePath: 'assets/gallery1.jpg',
            likeCount: 34,
            aspectRatio: 0.86,
          ),
          ProfileMomentData(
            id: 'gallery-6',
            imagePath: 'assets/gallery4.jpg',
            likeCount: 63,
            aspectRatio: 1.28,
          ),
          ProfileMomentData(
            id: 'gallery-7',
            imagePath: 'assets/gallery2.jpg',
            likeCount: 92,
            aspectRatio: 0.84,
          ),
          ProfileMomentData(
            id: 'gallery-8',
            imagePath: 'assets/gallery3.jpg',
            likeCount: 57,
            aspectRatio: 1.55,
          ),
        ],
      ),
      onTabSelected: onTabSelected ?? (index) {},
      onAddPressed: onAddPressed ?? () {},
      onRetry: () {},
    );
  }

  final ProfileData profile;
  final ProfileViewState viewState;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final VoidCallback onRetry;
  final String errorMessage;
  final WidgetBuilder? settingsBuilder;
  final VoidCallback? onSettingsClosed;
  final Widget Function(BuildContext context, ProfileMomentData moment)?
  momentDetailBuilder;
  final ValueChanged<ProfileMomentData>? onMomentPressed;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _horizontalPadding = 14;
  int _selectedProfileTab = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNavigationBar(
          key: ProfileKeys.bottomNavigation,
          selectedIndex: 3,
          onTabSelected: widget.onTabSelected,
          onAddPressed: widget.onAddPressed,
        ),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final safeTop = MediaQuery.paddingOf(context).top;
              // A compact header gives Overview content visible space, while
              // leaving enough height for avatar/name/bio/stats on 320x568.
              final headerExtent = safeTop + 232.0;
              final gradientHeight = headerExtent + 64;

              return Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: gradientHeight,
                    child: const DecoratedBox(
                      key: ProfileKeys.gradientBackground,
                      decoration: BoxDecoration(
                        gradient: ProfileSummaryHeader.profileGradient,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x00F9F9F9),
                              Color(0x00F9F9F9),
                              Color(0xD9F9F9F9),
                              AppColors.background,
                            ],
                            stops: <double>[0, 0.56, 0.91, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  CustomScrollView(
                    key: ProfileKeys.scrollView,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: ProfileSummaryHeader(
                          profile: widget.profile,
                          height: headerExtent,
                          horizontalPadding: 20,
                          topPadding: 6,
                          showSettingsButton: true,
                          onSettingsPressed: () => _openSettings(context),
                          avatarKey: ProfileKeys.avatar,
                          statsKey: ProfileKeys.stats,
                          settingsButtonKey: ProfileKeys.settingsButton,
                        ),
                      ),
                      SliverToBoxAdapter(child: _profileTabControl()),
                      ..._contentSlivers(),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileTabControl() {
    const tabLabels = <String>['Overview', 'Places', 'Moments'];
    const tabKeys = <Key>[
      ProfileKeys.overviewTab,
      ProfileKeys.placesTab,
      ProfileKeys.momentsTab,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        0,
        _horizontalPadding,
        1,
      ),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xBFFFFFFF)),
        ),
        child: Row(
          children: <Widget>[
            for (var index = 0; index < tabLabels.length; index++)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    key: tabKeys[index],
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {
                      if (_selectedProfileTab == index) return;
                      setState(() => _selectedProfileTab = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: _selectedProfileTab == index
                            ? ProfileSummaryHeader.profileGradient
                            : null,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        tabLabels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _selectedProfileTab == index
                              ? Colors.white
                              : const Color(0xFF626982),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers() {
    switch (widget.viewState) {
      case ProfileViewState.loading:
        return const <Widget>[
          SliverToBoxAdapter(
            child: _ProfileMessageState(
              key: ProfileKeys.loadingState,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ];
      case ProfileViewState.error:
        return <Widget>[
          SliverToBoxAdapter(
            child: _ProfileErrorState(
              key: ProfileKeys.errorState,
              message: widget.errorMessage,
              onRetry: widget.onRetry,
            ),
          ),
        ];
      case ProfileViewState.empty:
        return const <Widget>[
          SliverToBoxAdapter(
            child: _ProfileMessageState(
              key: ProfileKeys.emptyState,
              child: Text(
                'No Moments yet',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ];
      case ProfileViewState.populated:
        if (_selectedProfileTab == 2) return _gallerySlivers();
        return <Widget>[
          SliverToBoxAdapter(
            child: ProfileOverviewSections(
              profile: widget.profile,
              placesOnly: _selectedProfileTab == 1,
              onMomentPressed: (moment) => _openMoment(context, moment),
              onSeeAllMoments: () => setState(() => _selectedProfileTab = 2),
              onSeeFriends: _openFriends,
              onOpenOrbit: () => widget.onTabSelected(1),
              onSeeAllPlaces: () => setState(() => _selectedProfileTab = 1),
            ),
          ),
        ];
    }
  }

  List<Widget> _gallerySlivers() {
    if (widget.profile.moments.isEmpty) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: _ProfileMessageState(
            key: ProfileKeys.emptyState,
            child: Text(
              'No Moments yet',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        key: ProfileKeys.gallery,
        padding: const EdgeInsets.fromLTRB(
          _horizontalPadding,
          10,
          _horizontalPadding,
          0,
        ),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childCount: widget.profile.moments.length,
          itemBuilder: (context, index) {
            final moment = widget.profile.moments[index];
            return ProfileMomentTile(
              key: ProfileKeys.moment(moment.id),
              moment: moment,
              onTap: () => _openMoment(context, moment),
            );
          },
        ),
      ),
    ];
  }

  Future<void> _openSettings(BuildContext context) async {
    final customBuilder = widget.settingsBuilder;
    await Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder:
            customBuilder ??
            (_) => SettingsScreen(
              profile: widget.profile,
              onTabSelected: widget.onTabSelected,
              onAddPressed: widget.onAddPressed,
            ),
      ),
    );
    if (mounted) widget.onSettingsClosed?.call();
  }

  void _openMoment(BuildContext context, ProfileMomentData moment) {
    widget.onMomentPressed?.call(moment);
    final builder = widget.momentDetailBuilder;
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: builder == null
            ? (_) => ProfileMomentDetailScreen(moment: moment)
            : (detailContext) => builder(detailContext, moment),
      ),
    );
  }

  void _openFriends() {
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(builder: (_) => FriendsScreen.demo()),
    );
  }
}

class _ProfileMessageState extends StatelessWidget {
  const _ProfileMessageState({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
      child: Center(child: child),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
