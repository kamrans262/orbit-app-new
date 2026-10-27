import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../circles/data/orbit_circle_repository.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../circles/presentation/widgets/orbit_circle_confirmation.dart';
import '../../friends/data/orbit_social_repository.dart';
import '../../profile/presentation/widgets/orbit_dropdown_field.dart';
import '../data/orbit_location_models.dart';
import '../data/orbit_location_repository.dart';

/// Uses the existing Orbit full-width Circle sheet and standard confirmation.
Future<bool?> showOrbitLocationShareSheet({
  required BuildContext context,
  required OrbitLocationRepository repository,
  required OrbitLocationCapabilities capabilities,
}) => showOrbitCircleSheet<bool>(context:context,title:'Share your location',
  builder:(sheet)=>OrbitLocationShareForm(
    repository:repository,capabilities:capabilities));

class OrbitLocationShareForm extends StatefulWidget {
  const OrbitLocationShareForm({super.key,required this.repository,required this.capabilities,
    this.social,this.circles});
  final OrbitLocationRepository repository;
  final OrbitLocationCapabilities capabilities;
  final OrbitSocialRepository? social;
  final OrbitCircleRepository? circles;
  @override
  State<OrbitLocationShareForm> createState()=>_OrbitLocationShareFormState();
}
class _OrbitLocationShareFormState extends State<OrbitLocationShareForm> {
  String _type='person',_target='',_precision='approximate',_duration='one_hour';
  Map<String,String> _friends={},_circles={};
  bool _busy=true,_creating=false;
  String? _error;
  late final OrbitSocialRepository _social=widget.social??OrbitSocialRepository();
  late final OrbitCircleRepository _circlesRepo=widget.circles??OrbitCircleRepository();

  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(mounted)setState((){_busy=true;_error=null;});
    try {
      final people=<String,String>{},circles=<String,String>{};
      for(var page=1;page<=20;page++){
        final result=await _social.friends(page:page);
        for(final p in result.items)people[p.id]=p.name;
        if(!result.hasMore)break;
      }
      for(var page=1;page<=20;page++){
        final result=await _circlesRepo.list(page:page);
        for(final c in result.items)circles[c.id]=c.name;
        if(!result.hasMore)break;
      }
      if(mounted)setState((){_friends=people;_circles=circles;_busy=false;});
    }catch(_){
      if(mounted)setState((){
        _friends={};_circles={};_busy=false;
        _error='Could not verify available friends and Circles. Retry when connected.';
      });
    }
  }

  Map<String,String> get _eligible=>_type=='person'?_friends:_circles;
  String _label(String id,String value)=>value+' · '+id.substring(0,id.length<8?id.length:8);

  Future<void> _submit() async {
    if(_creating||_busy||!_eligible.containsKey(_target)||!widget.capabilities.global.canShare)return;
    final who=_eligible[_target]!;
    final durationDescription=switch(_duration){
      'one_hour'=>'one hour',
      'until_tonight'=>'until tonight (your device timezone)',
      'until_leaving'=>'until you leave the selected radius',
      'always'=>'until you stop manually, including future sessions',
      _=>'until you stop manually'
    };
    final confirmed=await showOrbitCircleConfirmation(context:context,
      title:'Confirm location sharing',
      description:'Share '+_precision+' location with '+who+' ('+_type+
        ') for '+durationDescription+'? Only you can stop it. Location is sent only while Orbit is foregrounded; no live WebSocket service is available.',
      confirmLabel:'Start sharing');
    if(!confirmed||!mounted)return;
    setState(()=>_creating=true);
    try{
      String? timezone;
      if(_duration=='until_tonight') {
        timezone=(await FlutterTimezone.getLocalTimezone()).identifier;
        if(timezone.trim().isEmpty)throw const FormatException('Timezone unavailable.');
      }
      await widget.repository.create(audienceType:_type,audienceId:_target,
        precision:_precision,duration:_duration,timezone:timezone,
        exitRadius:_duration=='until_leaving'?250:null);
      if(mounted)Navigator.of(context).pop(true);
    }catch(_){
      if(mounted)setState(()=>_error='Location sharing was not confirmed. Check privacy, permissions and connection.');
    }finally{if(mounted)setState(()=>_creating=false);}
  }

  @override
  Widget build(BuildContext context) {
    final map=_eligible;
    final names=map.keys.map((id)=>_label(id,map[id]!)).toList();
    final chosen=map.containsKey(_target)?_label(_target,map[_target]!):'Choose recipient';
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,
      children:[
        const Text('Sharing is off until you confirm. Circle membership alone never grants location.',
          style:TextStyle(fontFamily:AppTypography.fontFamily,fontSize:13,color:AppColors.textMuted)),
        const SizedBox(height:14),
        if(!widget.capabilities.global.canShare)
          const Text('Allow location in Privacy Settings and turn off Ghost Mode before sharing.',
            style:TextStyle(color:AppColors.textMuted)),
        if(_busy)const Padding(padding:EdgeInsets.all(22),
          child:Center(child:CircularProgressIndicator(color:AppColors.primaryEnd)))
        else ...[
          OrbitDropdownField(label:'Share with',value:_type=='person'?'One friend':'A Circle',
            items:const ['One friend','A Circle'],onChanged:(v)=>setState((){
              _type=v=='One friend'?'person':'circle';_target='';
              if(_duration=='always'&&_type=='circle')_duration='manual';
            })),
          const SizedBox(height:14),
          OrbitDropdownField(label:'Select trusted recipient',value:chosen,
            items:['Choose recipient',...names],onChanged:(value)=>setState((){
              _target=map.keys.firstWhere((id)=>_label(id,map[id]!)==value,orElse:()=>'');
            })),
          const SizedBox(height:14),
          OrbitDropdownField(label:'Precision',value:_precision=='precise'?'Precise':'Approximate',
            items:const ['Approximate','Precise'],onChanged:(v)=>
              setState(()=>_precision=v=='Precise'?'precise':'approximate')),
          const SizedBox(height:14),
          OrbitDropdownField(label:'Duration',value:_duration,
            items:['one_hour','until_tonight','manual',if(_type=='person')'always',
              if(widget.capabilities.untilLeaving)'until_leaving'],
            onChanged:(v)=>setState(()=>_duration=v)),
          const SizedBox(height:14),
          if(_duration=='until_leaving')
            const Text('Until leaving uses an approved 250m radius and reliable outside observations.',
              style:TextStyle(color:AppColors.textMuted)),
          if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),
            child:Text(_error!,style:const TextStyle(color:AppColors.textMuted))),
          const SizedBox(height:14),
          AppPrimaryButton(label:_creating?'Saving…':'Review & Share',
            enabled:!_creating&&widget.capabilities.global.canShare&&map.containsKey(_target),
            onPressed:()=>_submit()),
        ],
        if(_error!=null&&_busy==false)TextButton(onPressed:_load,child:const Text('Retry')),
      ]);
  }
}
