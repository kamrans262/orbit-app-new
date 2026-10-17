import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../domain/models/profile_models.dart';
import '../widgets/profile_moment_tile.dart';
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

  static Key moment(String id) => Key('profile_moment_$id');
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.profile,
    required this.onTabSelected,
    required this.onAddPressed,
    required this.onRetry,
    this.viewState = ProfileViewState.populated,
    this.errorMessage = 'Something went wrong. Please try again.',
    this.settingsBuilder,
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

  static const double _horizontalPadding = 28;

  final ProfileData profile;
  final ProfileViewState viewState;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;
  final VoidCallback onRetry;
  final String errorMessage;
  final WidgetBuilder? settingsBuilder;
  final Widget Function(BuildContext context, ProfileMomentData moment)?
  momentDetailBuilder;
  final ValueChanged<ProfileMomentData>? onMomentPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: AppBottomNavigationBar(
          key: ProfileKeys.bottomNavigation,
          selectedIndex: 3,
          onTabSelected: onTabSelected,
          onAddPressed: onAddPressed,
        ),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              final safeTop = MediaQuery.paddingOf(context).top;
              final referenceHeaderExtent = viewportHeight * 0.43;
              final compactMinimumExtent = safeTop + 330;
              final headerExtent = referenceHeaderExtent > compactMinimumExtent
                  ? referenceHeaderExtent
                  : compactMinimumExtent;
              final referenceGradientHeight = viewportHeight * 0.50;
              final gradientHeight = referenceGradientHeight > headerExtent + 44
                  ? referenceGradientHeight
                  : headerExtent + 44;

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
                          gradient: ProfileSummaryHeader.fadeToWhiteGradient,
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
                          profile: profile,
                          height: headerExtent,
                          showSettingsButton: true,
                          onSettingsPressed: () => _openSettings(context),
                          avatarKey: ProfileKeys.avatar,
                          statsKey: ProfileKeys.stats,
                          settingsButtonKey: ProfileKeys.settingsButton,
                        ),
                      ),
                      ..._buildGallerySlivers(),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

  List<Widget> _buildGallerySlivers() {
    switch (viewState) {
      case ProfileViewState.loading:
        return <Widget>[
          const SliverToBoxAdapter(
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
              message: errorMessage,
              onRetry: onRetry,
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
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: const <String>[
                    'Noto Color Emoji',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                  ],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ];
      case ProfileViewState.populated:
        if (profile.moments.isEmpty) {
          return const <Widget>[
            SliverToBoxAdapter(
              child: _ProfileMessageState(
                key: ProfileKeys.emptyState,
                child: Text(
                  'No Moments yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ];
        }
        return <Widget>[
          SliverPadding(
            key: ProfileKeys.gallery,
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: profile.moments.length,
              itemBuilder: (context, index) {
                final moment = profile.moments[index];
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
  }

  void _openSettings(BuildContext context) {
    final customBuilder = settingsBuilder;
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder:
            customBuilder ??
            (_) => SettingsScreen(
              profile: profile,
              onTabSelected: onTabSelected,
              onAddPressed: onAddPressed,
            ),
      ),
    );
  }

  void _openMoment(BuildContext context, ProfileMomentData moment) {
    onMomentPressed?.call(moment);
    final builder = momentDetailBuilder;
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: builder == null
            ? (_) => ProfileMomentDetailScreen(moment: moment)
            : (detailContext) => builder(detailContext, moment),
      ),
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
              fontFamilyFallback: const <String>[
                'Noto Color Emoji',
                'Apple Color Emoji',
                'Segoe UI Emoji',
              ],
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
