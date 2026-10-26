import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../profile/domain/models/profile_models.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/widgets/settings_list_item.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../data/orbit_social_repository.dart';
import 'orbit_friend_requests_screen.dart';
import '../widgets/orbit_social_confirmation.dart';

/// Authenticated person detail. A friend is never represented as a Circle.
/// Location, online status, photo and private bio are not part of M4 API.
class OrbitPersonScreen extends StatefulWidget {
  const OrbitPersonScreen({required this.person, super.key, this.repository});
  final OrbitPerson person;
  final OrbitSocialRepository? repository;

  @override
  State<OrbitPersonScreen> createState() => _OrbitPersonScreenState();
}

class _OrbitPersonScreenState extends State<OrbitPersonScreen> {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  late OrbitPerson _person = widget.person;
  bool _busy = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading || _busy) return;
    setState(() { _loading = true; _error = null; });
    try {
      final person = await _repo.preview(widget.person.id);
      if (mounted) setState(() => _person = person);
    } catch (_) {
      if (mounted) setState(() => _error = 'This person is unavailable or cannot be viewed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) =>
      confirmOrbitSocialAction(context,
        title: title, description: body,
        confirmation: action, destructive: true);

  Future<void> _mutate(Future<void> Function() action,
      {required String success}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      // Blocked people intentionally become unavailable after server success.
      if (success.startsWith('Blocked')) {
        Navigator.of(context).pop();
      } else {
        await _refreshAfterMutation();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is Exception
          ? 'Could not save the change. Your previous relationship is still active.'
          : 'Could not complete the request.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _refreshAfterMutation() async {
    try {
      final latest = await _repo.preview(widget.person.id);
      if (mounted) setState(() => _person = latest);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to verify the updated relationship.');
    }
  }

  void _futureFeature(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature will be available when its secured module is enabled. No data was shared.'),
    ));
  }

  Widget _futureAction(String name, IconData icon) => SettingsListItem(
    icon: icon,
    label: name,
    trailing: const Icon(Icons.lock_outline_rounded,
        size: 18, color: Color(0xFF64748B)),
    onTap: () => _futureFeature(name),
  );

  Future<void> _more() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppActionRow(
              leadingIcon: Icons.block,
              iconBackgroundColor: const Color(0xFFFEE2E2),
              leadingIconColor: const Color(0xFFB91C1C),
              title: 'Block user',
              onTap: () {
                Navigator.of(ctx).pop();
                _requestBlock();
              },
            ),
            const SizedBox(height: 12),
            AppActionRow(
              leadingIcon: Icons.flag_outlined,
              iconBackgroundColor: const Color(0xFFF2EAFE),
              leadingIconColor: const Color(0xFF7C3AED),
              title: 'Report user (moderation not yet available)',
              onTap: () {
                Navigator.of(ctx).pop();
                _futureFeature('Reporting');
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openRequests(String direction) async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder: (_) => OrbitFriendRequestsScreen(
        repository: _repo, initialDirection: direction),
    ));
    if (mounted) await _refresh();
  }

  Future<void> _requestBlock() async {
    if (await _confirm('Block ${_person.name}?',
        'This removes the friendship and protected access. Unblocking does not restore friendship.',
        'Block')) {
      await _mutate(() => _repo.block(_person.id), success: 'Blocked user.');
    }
  }

  Widget _quickActions(BuildContext context) {
    final friend = _person.relationship == 'friend';
    final outgoing = _person.relationship == 'outgoing_pending';
    final incoming = _person.relationship == 'incoming_pending';

    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: Color(0xFFB91C1C),
              )),
          ),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
        if (_error == null)
          SettingsListCard(
            key: const Key('friend_profile_quick_actions_card'),
            children: <Widget>[
              _futureAction('Message', Icons.chat_bubble_outline_rounded),
              _futureAction('Ping', Icons.notifications_active_outlined),
              _futureAction('Navigate', Icons.near_me_outlined),
              _futureAction('Check-In', Icons.location_on_outlined),
              SettingsListItem(
                icon: Icons.more_horiz_rounded, label: 'More', onTap: _more),
              SettingsListItem(
                icon: friend ? Icons.check_circle_outline_rounded
                    : Icons.person_add_alt_outlined,
                label: friend ? 'Friends'
                    : outgoing ? 'Manage sent request'
                    : incoming ? 'Review received request'
                    : 'Send friend request',
                trailing: friend
                    ? const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF7C3AED), size: 22)
                    : null,
                enabled: !_busy && !friend,
                onTap: _busy || friend ? () {}
                    : outgoing ? () => _openRequests('outgoing')
                    : incoming ? () => _openRequests('incoming')
                    : () => _mutate(() => _repo.sendRequest(_person.id),
                        success: 'Friend request sent.'),
              ),
              if (friend)
                SettingsListItem(
                  icon: Icons.person_remove_outlined,
                  label: 'Remove friend',
                  enabled: !_busy,
                  onTap: _busy ? () {} : () async {
                    if (await _confirm('Remove friend?',
                        'This will end your friendship.', 'Remove')) {
                      await _mutate(() => _repo.removeFriend(_person.id),
                          success: 'Friend removed.');
                    }
                  },
                ),
              SettingsListItem(
                icon: Icons.block, label: 'Block user',
                enabled: !_busy,
                  onTap: _busy ? () {} : () async {
                  if (await _confirm('Block ${_person.name}?',
                      'This removes the friendship and stops protected '
                      'interactions. Unblocking will not restore the friendship.',
                      'Block')) {
                    await _mutate(() => _repo.block(_person.id),
                        success: 'Blocked user.');
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Text(
          'Messaging, Ping, location and Circle membership require their '
          'own permissions and modules. Friendship alone does not enable sharing.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12, color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ProfileScreen(
    friendView: true,
    profile: ProfileData(
      id: _person.id,
      name: _person.name,
      bio: _person.username.isEmpty ? '' : '@${_person.username}',
      // The M4 person preview exposes no Circle/Friends/Moments counts.
      // These zeroes are never displayed in the friend-specific header.
      circleCount: 0, friendCount: 0, momentCount: 0,
      moments: const <ProfileMomentData>[],
    ),
    onFriendBack: () => Navigator.of(context).maybePop(),
    friendQuickActionsBuilder: _quickActions,
    onTabSelected: (_) {}, onAddPressed: () {}, onRetry: _refresh,
  );
}
