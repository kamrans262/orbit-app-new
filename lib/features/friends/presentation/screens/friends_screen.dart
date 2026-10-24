import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../circles/domain/models/friend_details_models.dart';
import '../../../circles/presentation/screens/friend_details_screen.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/favorite_person_tile.dart';

abstract final class FriendsKeys {
  static const scroll = Key('friends_scroll');
  static const headerTitle = Key('friends_header_title');
  static const searchButton = Key('friends_search_button');
  static const closeSearchButton = Key('friends_close_search_button');
  static const emptyState = Key('friends_empty_state');

  static Key row(String id) => Key('friends_row_$id');
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    required this.friends,
    this.onBack,
    this.onFriendPressed,
    this.onDiscover,
    this.onRequests,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.hasMore = false,
    this.onLoadMore,
    this.liveMode = false,
    this.offlineStale = false,
    super.key,
  });

  factory FriendsScreen.demo({
    VoidCallback? onBack,
    ValueChanged<FriendMemberData>? onFriendPressed,
  }) {
    return FriendsScreen(
      friends: const <FriendMemberData>[
        FriendMemberData(
          id: 'emma',
          name: 'Emma',
          status: 'Active now',
          imagePath: 'assets/Emma.png',
          isFavorite: true,
        ),
        FriendMemberData(
          id: 'mike',
          name: 'Mike',
          status: 'Active 5m ago',
          imagePath: 'assets/Mike.png',
        ),
        FriendMemberData(
          id: 'sophia',
          name: 'Sophia',
          status: 'Active 12m ago',
          imagePath: 'assets/Sophia.png',
          isFavorite: true,
        ),
      ],
      onBack: onBack,
      onFriendPressed: onFriendPressed,
    );
  }

  final List<FriendMemberData> friends;
  final VoidCallback? onBack;
  final ValueChanged<FriendMemberData>? onFriendPressed;
  final VoidCallback? onDiscover;
  final VoidCallback? onRequests;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final bool liveMode;
  final bool offlineStale;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerToListGap = 20;
  static const double _rowGap = 10;

  final OrbitSearchController _searchController = OrbitSearchController();

  late List<FriendMemberData> _friends;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _friends = List<FriendMemberData>.of(widget.friends);
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.friends, widget.friends)) {
      _friends = List<FriendMemberData>.of(widget.friends);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FriendMemberData> get _visibleFriends {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _friends;
    }

    return _friends
        .where((friend) {
          return friend.name.toLowerCase().contains(query) ||
              friend.status.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleFriends = _visibleFriends;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  _topPadding,
                  _horizontalPadding,
                  0,
                ),
                child: OrbitSearchableHeader(
                  compactTitle: true,
                  title: 'Friends',
                  placeholder: 'Search friends',
                  controller: _searchController,
                  onQueryChanged: (value) {
                    setState(() => _query = value);
                  },
                  onBack: widget.onBack,
                  searchSemanticLabel: widget.liveMode ? 'Find friends' : null,
                  onSearchPressed: widget.liveMode
                      ? (widget.onDiscover ?? () {
                          // Offline snapshots are read-only and never trigger
                          // discovery, even if the cached friends list is visible.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reconnect to find friends.'),
                            ),
                          );
                        })
                      : null,
                  trailingActions: <Widget>[
                    if (widget.onRequests != null)
                      AppCircularIconButton(
                        semanticLabel: 'Friend requests',
                        icon: Icons.person_add_alt_outlined,
                        iconSize: 20,
                        iconColor: const Color(0xFF7C3AED),
                        size: 40,
                        onPressed: widget.onRequests!,
                      ),
                  ],
                  titleKey: FriendsKeys.headerTitle,
                  searchButtonKey: FriendsKeys.searchButton,
                  closeButtonKey: FriendsKeys.closeSearchButton,
                ),
              ),
              const SizedBox(height: _headerToListGap),
              if (widget.offlineStale)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(children: [
                    const Text(
                      'OFFLINE • READ ONLY • Saved friends may be out of date.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    TextButton(
                      onPressed: widget.isLoading ? null : widget.onRetry,
                      child: const Text('Reconnect and verify'),
                    ),
                  ]),
                ),
              Expanded(
                child: widget.isLoading && visibleFriends.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : widget.errorMessage != null && visibleFriends.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.errorMessage!, textAlign: TextAlign.center),
                              TextButton(onPressed: widget.onRetry, child: const Text('Try again')),
                            ]))
                        : visibleFriends.isEmpty
                            ? const _FriendsEmptyState()
                            : ListView.separated(
                        key: FriendsKeys.scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(
                          _horizontalPadding,
                          0,
                          _horizontalPadding,
                          28,
                        ),
                        itemCount: visibleFriends.length + (widget.hasMore ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: _rowGap),
                        itemBuilder: (context, index) {
                          if (index == visibleFriends.length) {
                            return Center(child: TextButton(
                              onPressed: widget.isLoading ? null : widget.onLoadMore,
                              child: Text(widget.isLoading ? 'Loading…' : 'Load more'),
                            ));
                          }
                          final friend = visibleFriends[index];
                          return KeyedSubtree(
                            key: FriendsKeys.row(friend.id),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                splashFactory: NoSplash.splashFactory,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: FavoritePersonTile(
                                data: FavoritePersonData(
                                  id: friend.id,
                                  name: friend.name,
                                  status: friend.status,
                                  imagePath: friend.imagePath ?? '',
                                  isFavorite: friend.isFavorite,
                                ),
                                onTap: () { if (!widget.offlineStale) _openFriend(friend); },
                                onFavoritePressed: () =>
                                    _toggleFavorite(friend.id),
                                showFavoriteAction: !widget.liveMode,
                              ),
                            ),
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

  void _toggleFavorite(String id) {
    final index = _friends.indexWhere((friend) => friend.id == id);
    if (index < 0) {
      return;
    }

    final current = _friends[index];
    final updated = current.copyWith(isFavorite: !current.isFavorite);
    setState(() => _friends[index] = updated);
    updated.onFavoriteTap?.call(updated);
  }

  void _openFriend(FriendMemberData friend) {
    if (widget.liveMode && widget.onFriendPressed == null) return;
    final override = widget.onFriendPressed;
    if (override != null) {
      override(friend);
      return;
    }

    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (context) => FriendDetailsScreen(
          circleName: friend.name,
          members: _friends,
          groups: const <CircleGroupData>[],
          onBack: () => Navigator.of(context).maybePop(),
          onAddMember: () {},
        ),
      ),
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: FriendsKeys.emptyState,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No friends found',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
