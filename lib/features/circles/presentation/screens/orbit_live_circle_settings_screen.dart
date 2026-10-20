import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_circle_repository.dart';
import '../../domain/models/circle_settings.dart';
import 'circle_setting_screen.dart';
import 'orbit_live_circle_manage_screen.dart';
import 'orbit_live_circle_invites_screen.dart';

class OrbitLiveCircleSettingsScreen extends StatefulWidget {
  const OrbitLiveCircleSettingsScreen({required this.circle,super.key,this.repository});
  final OrbitCircle circle;
  final OrbitCircleRepository? repository;
  @override
  State<OrbitLiveCircleSettingsScreen> createState()=>_OrbitLiveCircleSettingsScreenState();
}

class _OrbitLiveCircleSettingsScreenState extends State<OrbitLiveCircleSettingsScreen> {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  late OrbitCircle _circle=widget.circle;
  Timer? _debounce;
  Future<void>? _saveInFlight;
  CircleSettings? _pending;
  @override
  void dispose(){_debounce?.cancel();super.dispose();}

  int _color(String? input) {
    final value=input?.replaceFirst('#','') ?? '';
    final rgb=int.tryParse(value,radix:16);
    return rgb == null ? 0xFF4D6EF5 : (0xFF000000|rgb);
  }
  String _hex(int color) => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6,'0').toUpperCase()}';

  CircleSettings get _settings=>CircleSettings(
    id:_circle.id,name:_circle.name,memberCount:_circle.memberCount,
    colorValue:_color(_circle.colorValue),
    liveLocationEnabled:false,momentSharingEnabled:false,
    pingEnabled:false,sosAlertsEnabled:false,
  );

  void _error(Object e) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(e is OrbitIdentityException ? e.message :
        'Could not save Circle changes. Reconnect and try again.')));
  }

  void _onChanged(CircleSettings next) {
    if (!_circle.can('edit')) return;
    _pending = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds:650), () {
      _persist();
    });
  }

  Future<bool> _persist() async {
    final inFlight = _saveInFlight;
    if (inFlight != null) {
      try { await inFlight; } catch (_) {}
    }
    if (!mounted) return false;
    final next = _pending;
    if (next == null) return true;
    final name=next.name.trim();
    if(name.isEmpty || name.length>80) {
      _error(const FormatException('Circle name must be between 1 and 80 characters.'));
      return false;
    }
    _pending=null;
    final task=() async {
      final updated=await _repo.update(_circle.id,
        name:name,color:_hex(next.colorValue));
      if(mounted) setState(()=>_circle=updated);
    }();
    _saveInFlight=task;
    try {
      await task;
    } catch(e) {
      _pending=next;
      _error(e);
      return false;
    } finally {
      if (identical(_saveInFlight,task)) _saveInFlight=null;
    }
    return _pending == null ? true : _persist();
  }

  Future<void> _back() async {
    _debounce?.cancel();
    if(await _persist() && mounted)Navigator.of(context).maybePop();
  }

  Future<void> _manage() async {
    _debounce?.cancel();
    if(!await _persist() || !mounted) return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveCircleManageScreen(circle:_circle,repository:_repo)));
    if(!mounted) return;
    try {
      final updated=await _repo.detail(_circle.id);
      if(mounted) setState(()=>_circle=updated);
    } catch (_) {
      if(mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _invites() async {
    _debounce?.cancel();
    if(!await _persist() || !mounted) return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveCircleInvitesScreen(circle:_circle,repository:_repo)));
  }

  Future<void> _archive() async {
    _debounce?.cancel();
    if(!await _persist() || !mounted)return;
    try {
      await _repo.archive(_circle.id);
      if(mounted) Navigator.of(context).pop();
    } catch(e){_error(e);}
  }

  @override
  Widget build(BuildContext context) {
    // Role-scoped: members cannot edit the settings form.
    if(!_circle.can('edit')){
      return OrbitLiveCircleManageScreen(circle:_circle,repository:_repo);
    }
    return CircleSettingScreen(
      settings:_settings,
      sharingControlsEnabled:false,
      archiveInsteadOfDelete:true,
      showDestructiveAction:_circle.can('archive'),
      onBack:_back,
      onSettingsChanged:_onChanged,
      onDeleteConfirmed:(_)=>_archive(),
      onInviteManagementPressed:_circle.can('invite') ? _invites : null,
      onManagePressed:_manage,
    );
  }
}
