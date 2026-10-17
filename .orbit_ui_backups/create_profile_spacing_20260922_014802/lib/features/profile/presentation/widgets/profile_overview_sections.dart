import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/profile_models.dart';
import 'profile_media_image.dart';

/// Profile Overview and Places tab content. All place/activity labels in these
/// two sections are explicit local demo content until the backend is connected.
class ProfileOverviewSections extends StatelessWidget {
  const ProfileOverviewSections({
    required this.profile,
    required this.onMomentPressed,
    required this.onSeeAllMoments,
    required this.onSeeFriends,
    required this.onOpenOrbit,
    required this.onSeeAllPlaces,
    this.placesOnly = false,
    super.key,
  });

  final ProfileData profile;
  final ValueChanged<ProfileMomentData> onMomentPressed;
  final VoidCallback onSeeAllMoments;
  final VoidCallback onSeeFriends;
  final VoidCallback onOpenOrbit;
  final VoidCallback onSeeAllPlaces;
  final bool placesOnly;

  static const Color _ink = AppColors.textPrimary;
  static const Color _grey = AppColors.textMuted;
  static const Color _purple = AppColors.primaryEnd;
  static const Color _border = Color(0xFFEDECF5);
  static const TextStyle _sectionTitle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 1.3,
    color: _ink,
  );
  static const TextStyle _small = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 10,
    height: 1.35,
    color: _grey,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildOrbitCard(context),
          const SizedBox(height: 9),
          _buildRecentlyBeenCard(context),
          if (!placesOnly) ...<Widget>[
            const SizedBox(height: 9),
            _buildHighlightsCard(context),
            const SizedBox(height: 9),
            _buildLatestMomentsCard(context),
          ],
        ],
      ),
    );
  }

  Widget _buildOrbitCard(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            icon: Icons.explore_outlined,
            title: 'My Orbit',
            subtitle: 'Places that make my story',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _grey,
            ),
            onTap: onOpenOrbit,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Demo map of Los Angeles with Santa Monica, Westwood and Downtown. Open Orbits',
            button: true,
            child: InkWell(
              onTap: onOpenOrbit,
              borderRadius: BorderRadius.circular(15),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  height: 128,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.asset(
                            'assets/orbit_map.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFEAF1F6),
                              child: Center(
                                child: Icon(
                                  Icons.map_outlined,
                                  size: 36,
                                  color: _grey,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: width * 0.18,
                            top: 43,
                            child: const _DemoMapPin(label: 'Santa Monica'),
                          ),
                          Positioned(
                            left: width * 0.45,
                            top: 8,
                            child: const _DemoMapPin(label: 'Westwood'),
                          ),
                          Positioned(
                            right: width * 0.07,
                            top: 31,
                            child: const _DemoMapPin(label: 'Downtown'),
                          ),
                          Positioned(
                            left: width * 0.69,
                            top: 72,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _purple,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x55000000),
                                    blurRadius: 7,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 7,
                            bottom: 7,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xF2FFFFFF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.near_me_rounded,
                                    color: _purple,
                                    size: 11,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Los Angeles · Demo',
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 9,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyBeenCard(BuildContext context) {
    const places = <_DemoPlace>[
      _DemoPlace('Downtown', 'Today', 'assets/gallery4.jpg'),
      _DemoPlace('Santa Monica', 'This week', 'assets/gallery1.jpg'),
      _DemoPlace('Bay Trail', '2d ago', 'assets/gallery3.jpg'),
    ];
    return _Card(
      child: Column(
        children: <Widget>[
          _SectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Recently Been',
            trailing: TextButton(
              onPressed: onSeeAllPlaces,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 36),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('See All', style: _small),
                  Icon(Icons.chevron_right_rounded, size: 14, color: _grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (var i = 0; i < places.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Material(
                    color: const Color(0xFFF7F6FD),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _showDemoLocation(
                        context,
                        places[i].name,
                        'Demo location · Los Angeles',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: <Widget>[
                            ClipOval(
                              child: ProfileMediaImage(
                                assetPath: places[i].image,
                                width: 30,
                                height: 30,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    places[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 9,
                                      color: _ink,
                                    ),
                                  ),
                                  Text(
                                    places[i].when,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _small,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsCard(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
          const _SectionHeader(icon: Icons.bolt_rounded, title: 'Highlights'),
          const SizedBox(height: 5),
          _HighlightRow(
            icon: Icons.photo_outlined,
            title: '3 Moments this week',
            subtitle: 'Exploring, food, and good company',
            onTap: onSeeAllMoments,
          ),
          const Divider(height: 1, color: _border),
          _HighlightRow(
            icon: Icons.people_alt_outlined,
            title: 'Dinner with Olivia',
            subtitle: 'West Hollywood · 1d ago',
            onTap: () => _showDemoLocation(
              context,
              'Dinner with Olivia',
              'West Hollywood · Demo activity',
            ),
          ),
          const Divider(height: 1, color: _border),
          _HighlightRow(
            icon: Icons.people_outline_rounded,
            title: '2 friends nearby',
            subtitle: 'At Santa Monica · Demo',
            onTap: onSeeFriends,
          ),
        ],
      ),
    );
  }

  Widget _buildLatestMomentsCard(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
          _SectionHeader(
            icon: Icons.image_outlined,
            title: 'Latest Moments',
            trailing: TextButton(
              onPressed: onSeeAllMoments,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 36),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('See All', style: _small),
                  Icon(Icons.chevron_right_rounded, size: 14, color: _grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (profile.moments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No Moments yet', style: _small),
            )
          else
            SizedBox(
              height: 104,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 8) / 2;
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profile.moments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final moment = profile.moments[index];
                      return SizedBox(
                        key: Key('profile_moment_${moment.id}'),
                        width: itemWidth,
                        child: Material(
                          color: const Color(0xFFF4F2FA),
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onMomentPressed(moment),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                ProfileMediaImage(
                                  assetPath: moment.imagePath,
                                  imageUrl: moment.imageUrl,
                                  width: itemWidth,
                                  height: 104,
                                  fit: BoxFit.cover,
                                ),
                                const Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: <Color>[
                                          Color(0xB8000000),
                                          Color(0x00000000),
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(8, 16, 8, 5),
                                      child: Text(
                                        'Santa Monica · Demo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 9,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showDemoLocation(
    BuildContext context,
    String title,
    String description,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppTypography.smallHeading),
              const SizedBox(height: 8),
              Text(description, style: AppTypography.bodyMuted),
              const SizedBox(height: 12),
              const Text(
                'This is sample location/activity data. Live places will appear when the backend is connected.',
                style: _small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDECF5), width: 1),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x090D1726),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(9), child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFF0E8FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.primaryEnd),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileOverviewSections._sectionTitle,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileOverviewSections._small,
                  ),
              ],
            ),
          ),
        ),
        if (trailing != null)
          if (onTap != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: trailing!,
            )
          else
            trailing!,
      ],
    );
  }
}

class _DemoMapPin extends StatelessWidget {
  const _DemoMapPin({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.location_on_rounded,
          size: 16,
          color: AppColors.primaryEnd,
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 68),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xEBFFFFFF),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 8,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoPlace {
  const _DemoPlace(this.name, this.when, this.image);
  final String name;
  final String when;
  final String image;
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0E8FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: AppColors.primaryEnd),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileOverviewSections._small,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
