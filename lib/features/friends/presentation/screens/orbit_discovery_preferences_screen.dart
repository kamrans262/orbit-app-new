import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../data/orbit_social_repository.dart';

/// M4 privacy settings: server-confirmed changes, never optimistic consent.
abstract final class OrbitDiscoveryHeaderKeys {
  static const back = Key('orbit_friend_discovery_header_back');
  static const title = Key('orbit_friend_discovery_header_title');
}

class OrbitDiscoveryPreferencesScreen extends StatefulWidget {
  const OrbitDiscoveryPreferencesScreen({super.key,this.repository});
  final OrbitSocialRepository? repository;
  @override
  State<OrbitDiscoveryPreferencesScreen> createState() => _OrbitDiscoveryPreferencesScreenState();
}

class _OrbitDiscoveryPreferencesScreenState extends State<OrbitDiscoveryPreferencesScreen> {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  Map<String,dynamic>? _prefs;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _repo.discoverySettings();
      if (mounted) setState(() => _prefs = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'Discovery settings could not be loaded.');
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _toggle(String key, bool next) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _repo.updateDiscovery({key:next});
      if (mounted) setState(() => _prefs = result);
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'Your change was not saved. The previous setting remains active.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String key,String title,IconData icon) {
    return AppActionRow(
      leadingIcon:icon,
      iconBackgroundColor: const Color(0xFFF2EAFE),
      leadingIconColor:const Color(0xFF7C3AED),
      title:title,
      toggleValue:_prefs?[key] == true,
      onToggleChanged:(value) => _toggle(key,value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: ListView(
        padding:const EdgeInsets.all(20),
        children: [
          const AppScreenHeader(
            title: 'Friend Discovery',

            backButtonKey: OrbitDiscoveryHeaderKeys.back,
            titleKey: OrbitDiscoveryHeaderKeys.title,
          ),
          const SizedBox(height:18),
          const Text('Choose who can find you. Your phone contacts remain private and are never automatically uploaded.',
            style:TextStyle(fontSize:13,color:Color(0xFF64748B))),
          const SizedBox(height:18),
          if (_busy) const Center(child:CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!,textAlign:TextAlign.center,
              style:const TextStyle(color:Color(0xFFB91C1C))),
            TextButton(onPressed:_load,child:const Text('Retry')),
          ],
          if (_prefs != null) ...[
            IgnorePointer(
              ignoring:_busy,
              child: Column(children:[
                _row('discoverable','Appear in friend search',Icons.search_outlined),
                const SizedBox(height:10),
                _row('discoverable_by_name','Searchable by name',Icons.badge_outlined),
                const SizedBox(height:10),
                _row('discoverable_by_contacts','Allow opted-in contact matches',Icons.contacts_outlined),
                const SizedBox(height:10),
                _row('allow_friend_requests','Allow friend requests',Icons.person_add_alt_outlined),
              ]),
            ),
          ],
        ],
      )),
    );
  }
}
