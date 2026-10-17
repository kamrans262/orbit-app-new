import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/favorite_person_tile.dart';
import '../../domain/models/friend_details_models.dart';
import '../widgets/circle_group_card.dart';
import '../widgets/circle_group_segmented_control.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../group_chat/presentation/screens/group_chat_screen.dart';
import '../../../welcome/presentation/screens/invite_people_screen.dart';

abstract final class FriendDetailsKeys {
  static const backButton = Key('friend_details_back_button');
  static const title = Key('friend_details_title');
  static const addMemberButton = Key('friend_details_add_member_button');
  static const circleName = Key('friend_details_circle_name');
  static const memberCount = Key('friend_details_member_count');
  static const scrollView = Key('friend_details_scroll_view');
  static const retryButton = Key('friend_details_retry_button');

  static Key member(String id) => Key('friend_details_member_$id');
  static Key group(String id) => Key('friend_details_group_$id');
}

class FriendDetailsScreen extends StatefulWidget {
  const FriendDetailsScreen({
    required this.circleName,
    required this.members,
    required this.groups,
    required this.onBack,
    required this.onAddMember,
    this.initialSegment = FriendDetailsSegment.circle,
    this.viewState = FriendDetailsViewState.loaded,
    this.errorMessage = 'Something went wrong. Please try again.',
    this.onRetry,
    super.key,
  });

  factory FriendDetailsScreen.demo({
    VoidCallback? onBack,
    VoidCallback? onAddMember,
  }) {
    return FriendDetailsScreen(
      circleName: 'Best Friends',
      members: <FriendMemberData>[
        FriendMemberData(
          id: 'emma',
          name: 'Emma',
          status: 'Active now',
          imagePath: 'assets/Emma.png',
          isFavorite: true,
          onTap: () {},
        ),
        FriendMemberData(
          id: 'mike',
          name: 'Mike',
          status: 'Active 5m ago',
          imagePath: 'assets/Mike.png',
          onTap: () {},
        ),
        FriendMemberData(
          id: 'sophia',
          name: 'Sophia',
          status: 'Active 12m ago',
          imagePath: 'assets/Sophia.png',
          isFavorite: true,
          onTap: () {},
        ),
        FriendMemberData(
          id: 'finn',
          name: 'Finn',
          status: 'At Santa Monica Beach',
          imagePath: 'assets/Emma.png',
          onTap: () {},
        ),
        FriendMemberData(
          id: 'suzie',
          name: 'Suzie',
          status: 'Active 24m ago',
          imagePath: 'assets/Sophia.png',
          onTap: () {},
        ),
      ],
      groups: <CircleGroupData>[
        CircleGroupData(
          id: 'basketball',
          name: 'Basketball squad',
          memberCount: 6,
          memberAvatars: const <String?>[
            'assets/Emma.png',
            'assets/Mike.png',
            'assets/Sophia.png',
          ],
          isFavorite: true,
          onTap: () {},
        ),
        CircleGroupData(
          id: 'weekend',
          name: 'Weekend crew',
          memberCount: 25,
          memberAvatars: const <String?>[
            'assets/Mike.png',
            'assets/Sophia.png',
            'assets/Emma.png',
          ],
          onTap: () {},
        ),
        CircleGroupData(
          id: 'travel',
          name: 'Travel buddies',
          memberCount: 5,
          memberAvatars: const <String?>[
            'assets/Sophia.png',
            'assets/Emma.png',
            'assets/Mike.png',
          ],
          onTap: () {},
        ),
        CircleGroupData(
          id: 'college',
          name: 'College friends',
          memberCount: 9,
          memberAvatars: const <String?>[
            'assets/Emma.png',
            'assets/Sophia.png',
          ],
          onTap: () {},
        ),
      ],
      onBack: onBack ?? () {},
      onAddMember: onAddMember ?? () {},
    );
  }

  final String circleName;
  final List<FriendMemberData> members;
  final List<CircleGroupData> groups;
  final VoidCallback onBack;
  final VoidCallback onAddMember;
  final FriendDetailsSegment initialSegment;
  final FriendDetailsViewState viewState;
  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  State<FriendDetailsScreen> createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends State<FriendDetailsScreen> {
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _sectionGap = 20;
  static const double _listGap = 10;
  static const double _gridGap = 10;
  static const double _groupCardHeight = 137;

  late FriendDetailsSegment _segment;
  late List<FriendMemberData> _members;
  late List<CircleGroupData> _groups;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _members = List<FriendMemberData>.of(widget.members);
    _groups = List<CircleGroupData>.of(widget.groups);
  }

  @override
  void didUpdateWidget(covariant FriendDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.members, widget.members)) {
      _members = List<FriendMemberData>.of(widget.members);
    }
    if (!identical(oldWidget.groups, widget.groups)) {
      _groups = List<CircleGroupData>.of(widget.groups);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          key: FriendDetailsKeys.scrollView,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: _topPadding)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              sliver: SliverToBoxAdapter(child: _buildHeader()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              sliver: SliverToBoxAdapter(child: _buildSummary()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: CircleGroupSegmentedControl(
                  value: _segment,
                  onChanged: _handleSegmentChanged,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
            ..._buildDynamicContent(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  void _openInvitePeople() {
    widget.onAddMember();
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => InvitePeopleScreen(
          onInviteByContacts: () {},
          onInviteByQrCode: () {},
          onInviteByLink: () {},
          onInviteByUsername: () {},
          onAddPerson: (_) {},
          onOpenLogin: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          AppCircularIconButton(
            key: FriendDetailsKeys.backButton,
            semanticLabel: 'Back',
            onPressed: widget.onBack,
            icon: Icons.chevron_left_rounded,
            iconSize: 24,
            iconColor: Colors.black,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Friend Details',
              key: FriendDetailsKeys.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppCircularIconButton(
            key: FriendDetailsKeys.addMemberButton,
            semanticLabel: 'Add member',
            onPressed: _openInvitePeople,
            icon: Icons.person_add_alt_1_rounded,
            iconSize: 18,
            iconColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final cleanName = widget.circleName.trim();
    final name = cleanName.isEmpty ? 'Circle' : cleanName;
    final count = _members.length;
    final countLabel = count == 1 ? '1 member' : '$count members';

    return Column(
      children: <Widget>[
        Text(
          name,
          key: FriendDetailsKeys.circleName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1724),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          countLabel,
          key: FriendDetailsKeys.memberCount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: const <String>[
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji',
            ],
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDynamicContent() {
    switch (widget.viewState) {
      case FriendDetailsViewState.loading:
        return const <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FriendDetailsLoadingState(),
          ),
        ];
      case FriendDetailsViewState.error:
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FriendDetailsErrorState(
              message: widget.errorMessage,
              onRetry: widget.onRetry,
            ),
          ),
        ];
      case FriendDetailsViewState.loaded:
        return _segment == FriendDetailsSegment.circle
            ? _buildCircleSlivers()
            : _buildGroupSlivers();
    }
  }

  List<Widget> _buildCircleSlivers() {
    if (_members.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _FriendDetailsEmptyState(
            message: 'No members in this circle yet.',
          ),
        ),
      ];
    }

    final childCount = _members.length * 2 - 1;
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index.isOdd) {
              return const SizedBox(height: _listGap);
            }

            final memberIndex = index ~/ 2;
            final member = _members[memberIndex];
            return KeyedSubtree(
              key: FriendDetailsKeys.member(member.id),
              child: FavoritePersonTile(
                data: FavoritePersonData(
                  id: member.id,
                  name: member.name,
                  status: member.status,
                  imagePath: member.imagePath ?? '',
                  isFavorite: member.isFavorite,
                ),
                onTap: member.onTap ?? () {},
                onFavoritePressed: () => _toggleMemberFavorite(memberIndex),
              ),
            );
          }, childCount: childCount),
        ),
      ),
    ];
  }

  List<Widget> _buildGroupSlivers() {
    if (_groups.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _FriendDetailsEmptyState(
            message: 'No groups in this circle yet.',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _gridGap,
            mainAxisSpacing: _gridGap,
            mainAxisExtent: _groupCardHeight,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final group = _groups[index];
            return CircleGroupCard(
              key: FriendDetailsKeys.group(group.id),
              data: group,
              onTap: () => _openGroupChat(group),
              onFavoritePressed: () => _toggleGroupFavorite(index),
            );
          }, childCount: _groups.length),
        ),
      ),
    ];
  }

  void _openGroupChat(CircleGroupData group) {
    group.onTap?.call();
    Navigator.of(context, rootNavigator: true).push(
      AppFadeSlidePageRoute<void>(
        builder: (routeContext) => GroupChatScreen.demo(
          title: group.name,
          memberCount: group.memberCount,
          participantAvatars: group.memberAvatars,
          onBack: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  void _handleSegmentChanged(FriendDetailsSegment next) {
    if (_segment == next) {
      return;
    }
    setState(() => _segment = next);
  }

  void _toggleMemberFavorite(int index) {
    final current = _members[index];
    final updated = current.copyWith(isFavorite: !current.isFavorite);
    setState(() => _members[index] = updated);
    updated.onFavoriteTap?.call(updated);
  }

  void _toggleGroupFavorite(int index) {
    final current = _groups[index];
    final updated = current.copyWith(isFavorite: !current.isFavorite);
    setState(() => _groups[index] = updated);
    updated.onFavoriteTap?.call(updated);
  }
}

class _FriendDetailsLoadingState extends StatelessWidget {
  const _FriendDetailsLoadingState();

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

class _FriendDetailsEmptyState extends StatelessWidget {
  const _FriendDetailsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Text(
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
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _FriendDetailsErrorState extends StatelessWidget {
  const _FriendDetailsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              TextButton(
                key: FriendDetailsKeys.retryButton,
                onPressed: onRetry,
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
