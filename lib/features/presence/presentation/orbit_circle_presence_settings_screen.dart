import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_action_row.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../circles/presentation/widgets/circle_setting_toggle.dart';
import '../../circles/presentation/widgets/orbit_circle_confirmation.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../data/orbit_presence_models.dart';
import '../data/orbit_presence_repository.dart';

class OrbitCirclePresenceSettingsScreen extends StatefulWidget {
  const OrbitCirclePresenceSettingsScreen({required this.circleId,
    required this.circleName, super.key, this.repository});
  final String circleId;
  final String circleName;
  final OrbitPresenceRepository? repository;
  @override
  State<OrbitCirclePresenceSettingsScreen> createState() => _OrbitCirclePresenceSettingsScreenState();
}

class _OrbitCirclePresenceSettingsScreenState extends State<OrbitCirclePresenceSettingsScreen> {
  late final OrbitPresenceRepository _repo=widget.repository ?? OrbitPresenceRepository();
  OrbitPresencePreferences? _current;
  bool _enabled=false, _persistent=false, _loading=true, _saving=false;
  String? _error;
  int _epoch=0;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _epoch++; super.dispose(); }

  Future<void> _load() async {
    final epoch=++_epoch;
    setState(() {_loading=true;_error=null;});
    try {
      final p=await _repo.preferences();
      if (!mounted || epoch!=_epoch) return;
      final grant=p.forCircle(widget.circleId);
      setState(() {
        _current=p; _enabled=grant?.requested==true && grant?.expired!=true;
        _persistent=grant?.duration=='persistent'; _loading=false;
      });
    } catch (_) {
      if (!mounted || epoch!=_epoch) return;
      setState(() {_loading=false; _current=null;
        _error='Presence settings unavailable. Reconnect and try again.';});
    }
  }

  Future<void> _save() async {
    if (_saving || _current==null) return;
    if (_enabled) {
      final accepted=await showOrbitCircleConfirmation(
        context:context,title:'Share your online status?',
        description:'Only authorized members of ${widget.circleName} can see '
          'your current status when your global privacy settings permit it. '
          'You can revoke this permission at any time.',
        confirmLabel:'Allow sharing', cancelLabel:'Keep editing');
      if (!accepted || !mounted) return;
    }
    setState(()=>_saving=true);
    try {
      await _repo.circleConsent(widget.circleId,enabled:_enabled,
        duration:_enabled?(_persistent?'persistent':'until_expiry'):null,
        expiresAt:_enabled && !_persistent
          ? DateTime.now().toUtc().add(const Duration(hours:24)):null);
      if (!mounted) return;
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Presence preference saved.')));
    } on OrbitIdentityException catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Permission was not saved. Previous settings remain active.')));
    } finally {
      if (mounted) setState(()=>_saving=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Padding(padding:const EdgeInsets.symmetric(horizontal:20),
      child:Column(children:[
        const SizedBox(height:14),
        AppScreenHeader(title:'Presence',prominent:true,
          onBack:()=>Navigator.of(context).maybePop()),
        const SizedBox(height:25),
        Expanded(child:_loading
          ? const Center(child:CircularProgressIndicator(color:AppColors.primaryEnd))
          : _error!=null
          ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(_error!,textAlign:TextAlign.center,
                style:const TextStyle(fontFamily:AppTypography.fontFamily)),
              TextButton(onPressed:_load,child:const Text('Try again')),
            ]))
          : ListView(children:[
              Text(widget.circleName,style:const TextStyle(
                fontSize:18,fontWeight:FontWeight.w600,
                fontFamily:AppTypography.fontFamily,color:AppColors.textPrimary)),
              const SizedBox(height:16),
              const Text('Presence is private by default. '
                'Circle membership alone never permits activity sharing.',
                style:TextStyle(fontFamily:AppTypography.fontFamily,
                  color:AppColors.textMuted,fontSize:13)),
              const SizedBox(height:20),
              AppActionRow(title:'Share my online status',
                leadingIcon:Icons.visibility_outlined,
                leadingIconColor:AppColors.primaryEnd,
                iconBackgroundColor:AppColors.background,
                onTap:()=>setState(()=>_enabled=!_enabled),
                trailing:IgnorePointer(child:CircleSettingToggle(value:_enabled,
                  onChanged:(v)=>setState(()=>_enabled=v),
                  semanticLabel:'Circle Presence sharing'))),
              if (_enabled) ...[
                const SizedBox(height:16),
                AppActionRow(title:'Share for 24 hours',
                  leadingIcon:Icons.timer_outlined,
                  leadingIconColor:AppColors.primaryEnd,
                  iconBackgroundColor:AppColors.background,
                  onTap:()=>setState(()=>_persistent=false),
                  trailing:Icon(_persistent?Icons.radio_button_unchecked:
                    Icons.radio_button_checked,color:AppColors.primaryEnd)),
                const SizedBox(height:8),
                AppActionRow(title:'Until I revoke',
                  leadingIcon:Icons.shield_outlined,
                  leadingIconColor:AppColors.primaryEnd,
                  iconBackgroundColor:AppColors.background,
                  onTap:()=>setState(()=>_persistent=true),
                  trailing:Icon(_persistent?Icons.radio_button_checked:
                    Icons.radio_button_unchecked,color:AppColors.primaryEnd)),
              ],
              const SizedBox(height:20),
              if (!_current!.globalPermitsPresence)
                const Text('Ghost Mode or global Presence visibility is blocking '
                  'sharing. To appear online, update Profile > Settings > '
                  'Privacy Settings. This screen does not override global privacy.',
                  style:TextStyle(fontFamily:AppTypography.fontFamily,
                    color:AppColors.textMuted,fontSize:13)),
              const SizedBox(height:10),
              const Text('This never shares your location, enables SOS, '
                'or changes message permissions.',
                style:TextStyle(fontFamily:AppTypography.fontFamily,
                  color:AppColors.textMuted,fontSize:12)),
            ])),
        if (!_loading && _error==null) ...[
          AppPrimaryButton(label:_saving?'Saving...':'Save Presence setting',
            enabled:!_saving,onPressed:(){_save();}),
          const SizedBox(height:20),
        ],
      ]),
    )),
  );
}
