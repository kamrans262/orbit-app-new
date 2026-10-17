import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../domain/models/profile_models.dart';
import '../profile_settings_target.dart';
import '../widgets/profile_media_image.dart';
import '../widgets/profile_moment_tile.dart';
import 'profile_moment_detail_screen.dart';

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
            likeCount: 84,
          ),
          ProfileMomentData(
            id: 'gallery-2',
            imagePath: 'assets/gallery2.jpg',
            likeCount: 1430,
          ),
          ProfileMomentData(
            id: 'gallery-3',
            imagePath: 'assets/gallery3.jpg',
            likeCount: 32,
          ),
          ProfileMomentData(
            id: 'gallery-4',
            imagePath: 'assets/gallery4.jpg',
            likeCount: 219,
          ),
          ProfileMomentData(
            id: 'gallery-5',
            imagePath: 'assets/gallery2.jpg',
            likeCount: 5012,
          ),
          ProfileMomentData(
            id: 'gallery-more',
            imagePath: 'assets/gallery1.jpg',
            remainingCount: 202,
          ),
          ProfileMomentData(
            id: 'gallery-7',
            imagePath: 'assets/gallery4.jpg',
            likeCount: 125,
          ),
          ProfileMomentData(
            id: 'gallery-8',
            imagePath: 'assets/gallery3.jpg',
            likeCount: 97,
          ),
        ],
      ),
      onTabSelected: onTabSelected ?? (index) {},
      onAddPressed: onAddPressed ?? () {},
      onRetry: () {},
    );
  }

  static const double _horizontalPadding = 28;
  static const LinearGradient _profileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFED65C9), Color(0xFF7C3AED)],
  );

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
          child: CustomScrollView(
            key: ProfileKeys.scrollView,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: <Widget>[
              SliverToBoxAdapter(child: _buildProfileTop(context)),
              ..._buildGallerySlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTop(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _profileGradient),
      child: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  safeTop + 20,
                  _horizontalPadding,
                  0,
                ),
                child: Column(
                  children: <Widget>[
                    _ProfileAvatar(profile: profile),
                    const SizedBox(height: 10),
                    Text(
                      profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _ProfileStats(
                      key: ProfileKeys.stats,
                      circleCount: profile.circleCount,
                      friendCount: profile.friendCount,
                      momentCount: profile.momentCount,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: safeTop + 20,
                right: _horizontalPadding,
                child: AppCircularIconButton(
                  key: ProfileKeys.settingsButton,
                  onPressed: () => _openSettings(context),
                  icon: Icons.settings_outlined,
                  size: 30,
                  iconSize: 17,
                  iconColor: AppBottomNavigationBar.activeColor,
                  semanticLabel: 'Settings',
                ),
              ),
            ],
          ),
          Container(
            height: 78,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF7C3AED), Colors.white],
              ),
            ),
          ),
        ],
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
                return Transform.translate(
                  offset: const Offset(0, -28),
                  child: ProfileMomentTile(
                    key: ProfileKeys.moment(moment.id),
                    moment: moment,
                    onTap: () => _openMoment(context, moment),
                  ),
                );
              },
            ),
          ),
        ];
    }
  }

  void _openSettings(BuildContext context) {
    final builder = settingsBuilder ?? buildProfileSettingsTarget;
    Navigator.of(context)
        .push<void>(AppFadeSlidePageRoute<void>(builder: builder));
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      key: ProfileKeys.avatar,
      child: SizedBox.square(
        dimension: 80,
        child: ProfileMediaImage(
          assetPath: profile.imagePath,
          imageUrl: profile.imageUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          fallbackAspectRatio: 1,
        ),
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({
    required this.circleCount,
    required this.friendCount,
    required this.momentCount,
    super.key,
  });

  final int circleCount;
  final int friendCount;
  final int momentCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ProfileStat(label: 'Circle', value: circleCount),
        ),
        const _StatSeparator(),
        Expanded(
          child: _ProfileStat(label: 'Friends', value: friendCount),
        ),
        const _StatSeparator(),
        Expanded(
          child: _ProfileStat(label: 'Moments', value: momentCount),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: Color(0xE6FFFFFF),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            maxLines: 1,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatSeparator extends StatelessWidget {
  const _StatSeparator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 42,
      child: VerticalDivider(width: 1, thickness: 1, color: Color(0x42FFFFFF)),
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
