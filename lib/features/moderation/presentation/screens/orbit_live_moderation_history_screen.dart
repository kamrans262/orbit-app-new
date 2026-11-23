import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../friends/presentation/widgets/orbit_social_confirmation.dart';
import '../../../profile/presentation/widgets/settings_list_item.dart';
import '../../data/orbit_moderation_repository.dart';

/// M17 owner-only status surface composed entirely of Orbit's approved
/// Profile/Settings header, card, icon, typography and confirmation popup.
/// It cannot inspect another user's reports, moderator cases or E2EE evidence.
class OrbitLiveModerationHistoryScreen extends StatefulWidget {
  const OrbitLiveModerationHistoryScreen({super.key, this.repository});

  final OrbitModerationRepository? repository;

  @override
  State<OrbitLiveModerationHistoryScreen> createState() =>
      _OrbitLiveModerationHistoryScreenState();
}

class _OrbitLiveModerationHistoryScreenState
    extends State<OrbitLiveModerationHistoryScreen> {
  late final OrbitModerationRepository _repository =
      widget.repository ?? OrbitModerationRepository();

  List<OrbitModerationReceipt> _reports = const [];
  List<OrbitModerationAction> _actions = const [];
  List<OrbitModerationAppeal> _appeals = const [];
  String? _error;
  bool _loading = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading || _posting) return;
    setState(() {
      _loading = true;
      _error = null;
      // Never retain privileged owner data when a new refresh is starting.
      _reports = const [];
      _actions = const [];
      _appeals = const [];
    });
    try {
      final snapshot = await _repository.myHistory();
      if (!mounted) return;
      setState(() {
        _reports = snapshot.reports;
        _actions = snapshot.actions;
        _appeals = snapshot.appeals;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to load your reports and appeals. Reconnect and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _alreadyAppealed(String actionId) =>
      _appeals.any((appeal) => appeal.actionId == actionId);

  Future<void> _appeal(OrbitModerationAction action) async {
    if (_posting || action.status != 'active' ||
        _alreadyAppealed(action.id)) return;
    final accepted = await confirmOrbitSocialAction(
      context,
      title: 'Request a review?',
      description:
          'Submit an appeal for this specific moderation action. '
          'A separate moderator will review it. '
          'Your appeal is not confirmed until Orbit accepts the request.',
      confirmation: 'Submit Appeal',
      destructive: false,
    );
    if (!accepted || !mounted) return;
    setState(() => _posting = true);
    try {
      final receipt = await _repository.appeal(action.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(receipt.status == 'pending'
            ? 'Appeal received for independent review.'
            : 'Appeal status: ${receipt.status}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Appeal not confirmed. Please retry when connected.'),
      ));
    } finally {
      if (mounted) {
        setState(() => _posting = false);
        await _refresh();
      }
    }
  }

  Widget _section(String title, String subtitle, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: AppTypography.smallHeading),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTypography.bodyMuted),
            const SizedBox(height: 12),
            SettingsListCard(children: children.isEmpty
                ? <Widget>[
                    SettingsListItem(
                      icon: Icons.inbox_outlined,
                      label: 'No records available',
                      trailing: const SizedBox.shrink(),
                      enabled: false,
                      onTap: () {},
                    ),
                  ]
                : children),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: AppScreenHeader(title: 'Reports & Appeals'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  children: <Widget>[
                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )),
                    if (_error != null) ...<Widget>[
                      Text(_error!, style: AppTypography.body),
                      TextButton(onPressed: _refresh,
                          child: const Text('Try again')),
                    ],
                    if (!_loading && _error == null) ...<Widget>[
                      _section('Your reports',
                        'A received report is not a moderation decision.',
                        _reports.map((report) => SettingsListItem(
                          key: Key('moderation_report_${report.id}'),
                          icon: Icons.flag_outlined,
                          label: 'Report received • '
                              '${report.createdAt.toLocal().month}/'
                              '${report.createdAt.toLocal().day}',
                          trailing: const Icon(Icons.check_circle_outline),
                          enabled: false,
                          onTap: () {},
                        )).toList()),
                      _section('Actions affecting your account',
                        'Only current server-recorded moderation actions appear.',
                        _actions.map((action) => SettingsListItem(
                          key: Key('moderation_action_${action.id}'),
                          icon: Icons.gavel_outlined,
                          label: action.scope == 'messaging_send'
                            ? 'Messaging restriction • ${action.effectiveStatus}'
                            : 'Moderation warning • ${action.effectiveStatus}',
                          trailing: action.status == 'active' &&
                                  !_alreadyAppealed(action.id)
                              ? const Icon(Icons.chevron_right_rounded)
                              : const Icon(Icons.check_circle_outline),
                          enabled: action.status == 'active' &&
                              !_alreadyAppealed(action.id) && !_posting,
                          onTap: () => _appeal(action),
                        )).toList()),
                      _section('Appeals',
                        'Pending is not a decision. Only final server outcomes are shown.',
                        _appeals.map((appeal) => SettingsListItem(
                          key: Key('moderation_appeal_${appeal.id}'),
                          icon: Icons.fact_check_outlined,
                          label: 'Appeal • ${appeal.status}',
                          trailing: const SizedBox.shrink(),
                          enabled: false,
                          onTap: () {},
                        )).toList()),
                      Center(
                        child: TextButton.icon(
                          onPressed: _posting ? null : _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
