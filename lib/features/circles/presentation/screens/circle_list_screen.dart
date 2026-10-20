import 'package:flutter/material.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';
import '../../domain/models/friend_details_models.dart';
import '../widgets/circle_group_card.dart';
import 'friend_details_screen.dart';

enum CircleListViewState { loaded, loading, error }

abstract final class CircleListKeys {
  static const title = Key('circle_list_title');
  static const search = Key('circle_list_search');
  static const scroll = Key('circle_list_scroll');
  static const empty = Key('circle_list_empty');
  static const loading = Key('circle_list_loading');
  static const error = Key('circle_list_error');
  static const retry = Key('circle_list_retry');
  static const create = Key('circle_list_create');
  static const join = Key('circle_list_join');
  static Key circle(String id) => Key('circle_list_circle_$id');
}

/// Displays the circles of the authenticated user. The demo factory below is
/// purely presentational; production passes circles and callbacks from its
/// repository/state layer. It does not simulate membership or backend writes.
class CircleListScreen extends StatefulWidget {
  const CircleListScreen({
    required this.circles,
    this.onCirclePressed,
    this.onFavoriteChanged,
    this.enableFavoriteControls = true,
    this.onCreatePressed,
    this.onJoinRequested,
    this.onRetry,
    this.onBack,
    this.viewState = CircleListViewState.loaded,
    this.errorMessage = 'Unable to load your circles. Please try again.',
    super.key,
  });

  factory CircleListScreen.demo() => const CircleListScreen(
    circles: <CircleGroupData>[
      CircleGroupData(
        id: 'best-friends',
        name: 'Best Friends',
        memberCount: 3,
        memberAvatars: <String?>[
          'assets/Emma.png',
          'assets/Mike.png',
          'assets/Sophia.png',
        ],
        isFavorite: true,
      ),
      CircleGroupData(
        id: 'weekend-crew',
        name: 'Weekend crew',
        memberCount: 3,
        memberAvatars: <String?>[
          'assets/Mike.png',
          'assets/Sophia.png',
          'assets/Emma.png',
        ],
      ),
      CircleGroupData(
        id: 'travel-buddies',
        name: 'Travel buddies',
        memberCount: 2,
        memberAvatars: <String?>['assets/Sophia.png', 'assets/Emma.png'],
      ),
      CircleGroupData(
        id: 'basketball-squad',
        name: 'Basketball squad',
        memberCount: 3,
        memberAvatars: <String?>[
          'assets/Emma.png',
          'assets/Mike.png',
          'assets/Sophia.png',
        ],
      ),
    ],
  );

  final List<CircleGroupData> circles;
  final ValueChanged<CircleGroupData>? onCirclePressed;
  final ValueChanged<CircleGroupData>? onFavoriteChanged;
  final bool enableFavoriteControls;
  final VoidCallback? onCreatePressed;
  final ValueChanged<String>? onJoinRequested;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final CircleListViewState viewState;
  final String errorMessage;

  @override
  State<CircleListScreen> createState() => _CircleListScreenState();
}

class _CircleListScreenState extends State<CircleListScreen> {
  final OrbitSearchController _search = OrbitSearchController();
  late List<CircleGroupData> _circles;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _circles = List<CircleGroupData>.of(widget.circles);
  }

  @override
  void didUpdateWidget(covariant CircleListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.circles, widget.circles)) {
      _circles = List<CircleGroupData>.of(widget.circles);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CircleGroupData> get _visibleCircles {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _circles;
    return _circles
        .where((circle) => circle.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCircles;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: OrbitSearchableHeader(
                title: 'My Circles',
                placeholder: 'Search circles',
                controller: _search,
                onBack: widget.onBack,
                onQueryChanged: (value) => setState(() => _query = value),
                titleKey: CircleListKeys.title,
                searchButtonKey: CircleListKeys.search,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CustomScrollView(
                key: CircleListKeys.scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(child: _buildActions(context)),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (widget.viewState == CircleListViewState.loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          key: CircleListKeys.loading,
                        ),
                      ),
                    )
                  else if (widget.viewState == CircleListViewState.error)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _CircleListMessage(
                        key: CircleListKeys.error,
                        icon: Icons.wifi_off_rounded,
                        title: 'Your circles could not be loaded',
                        subtitle: widget.errorMessage,
                        action: widget.onRetry == null ? null : 'Try again',
                        actionKey: CircleListKeys.retry,
                        onAction: widget.onRetry,
                      ),
                    )
                  else if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _CircleListMessage(
                        key: CircleListKeys.empty,
                        icon: Icons.groups_outlined,
                        title: _query.trim().isEmpty
                            ? 'No circles yet'
                            : 'No matching circles',
                        subtitle: _query.trim().isEmpty
                            ? 'Create or join a circle to see your people here.'
                            : 'Try another circle name.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: width < 285 ? 1 : 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 137,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final circle = visible[index];
                              return CircleGroupCard(
                                key: CircleListKeys.circle(circle.id),
                                data: circle,
                                onTap: () => _openCircle(context, circle),
                                onFavoritePressed: !widget.enableFavoriteControls
                                    ? null : () => _toggleFavorite(circle.id),
                              );
                            }, childCount: visible.length),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _CircleActionButton(
            key: CircleListKeys.create,
            icon: Icons.add_rounded,
            label: 'Create Circle',
            onTap: () {
              if (widget.onCreatePressed != null) {
                widget.onCreatePressed!();
              } else {
                // Existing UI-only create flow; never simulates an API success.
                Navigator.of(context).pushNamed(AppRoutes.createCircle);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CircleActionButton(
            key: CircleListKeys.join,
            icon: Icons.link_rounded,
            label: 'Join Circle',
            onTap: () => _showJoinCircleSheet(context),
          ),
        ),
      ],
    );
  }

  void _showJoinCircleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _JoinCircleSheet(onJoinRequested: widget.onJoinRequested),
    );
  }

  void _toggleFavorite(String id) {
    final index = _circles.indexWhere((circle) => circle.id == id);
    if (index < 0) return;
    final circle = _circles[index];
    final updated = circle.copyWith(isFavorite: !circle.isFavorite);
    setState(() => _circles[index] = updated);
    widget.onFavoriteChanged?.call(updated);
  }

  void _openCircle(BuildContext context, CircleGroupData circle) {
    if (widget.onCirclePressed != null) {
      widget.onCirclePressed!(circle);
      return;
    }
    // Demo route only: the backend will supply the actual circle member roster
    // and the production onCirclePressed callback. Never pass demo data as real.
    final demoMembers = <FriendMemberData>[
      if (circle.memberAvatars.isNotEmpty)
        FriendMemberData(
          id: '${circle.id}-member-1',
          name: 'Emma',
          status: 'Active now',
          imagePath: circle.memberAvatars[0],
        ),
      if (circle.memberAvatars.length > 1)
        FriendMemberData(
          id: '${circle.id}-member-2',
          name: 'Mike',
          status: 'Active 5m ago',
          imagePath: circle.memberAvatars[1],
        ),
      if (circle.memberAvatars.length > 2)
        FriendMemberData(
          id: '${circle.id}-member-3',
          name: 'Sophia',
          status: 'Active 12m ago',
          imagePath: circle.memberAvatars[2],
        ),
    ];
    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(
        builder: (_) => FriendDetailsScreen(
          circleName: circle.name,
          members: demoMembers,
          groups: const <CircleGroupData>[],
          onBack: () => Navigator.of(context).maybePop(),
          onAddMember: () =>
              Navigator.of(context).pushNamed(AppRoutes.invitePeople),
        ),
      ),
    );
  }
}

class _JoinCircleSheet extends StatefulWidget {
  const _JoinCircleSheet({this.onJoinRequested});

  final ValueChanged<String>? onJoinRequested;

  @override
  State<_JoinCircleSheet> createState() => _JoinCircleSheetState();
}

class _JoinCircleSheetState extends State<_JoinCircleSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _validation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _validation = 'Enter an invitation code.');
      return;
    }
    final onJoin = widget.onJoinRequested;
    if (onJoin == null) {
      setState(
        () => _validation =
            'Joining will be available when the backend is connected.',
      );
      return;
    }
    Navigator.of(context).pop();
    onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Join Circle', style: AppTypography.smallHeading),
            const SizedBox(height: 10),
            Text(
              'Enter the invitation code shared with you.',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_validation != null) setState(() => _validation = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Invite code',
                errorText: _validation,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[
                      AppColors.primaryStart,
                      AppColors.primaryEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextButton(
                  onPressed: _submit,
                  child: const Text(
                    'Join Circle',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: AppColors.primaryEnd),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
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

class _CircleListMessage extends StatelessWidget {
  const _CircleListMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionKey,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.smallHeading,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            if (action != null && onAction != null) ...<Widget>[
              const SizedBox(height: 18),
              TextButton(
                key: actionKey,
                onPressed: onAction,
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
