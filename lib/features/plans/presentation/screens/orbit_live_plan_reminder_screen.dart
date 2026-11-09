import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_plan_repository.dart';

/// Reminders are an independent Plan preference. M14 push remains governed
/// separately by device notification permission and server FCM controls.
class OrbitLivePlanReminderScreen extends StatefulWidget {
  const OrbitLivePlanReminderScreen({super.key,this.repository});
  final OrbitPlanRepository? repository;
  @override
  State<OrbitLivePlanReminderScreen> createState()=>_OrbitLivePlanReminderScreenState();
}
class _OrbitLivePlanReminderScreenState extends State<OrbitLivePlanReminderScreen> {
  late final OrbitPlanRepository _repo=widget.repository??OrbitPlanRepository();
  bool _loading=true,_saving=false,_enabled=true;
  String? _error,_owner;
  final _offsets=<int>{};
  List<int> _allowed=const [0,15,60,1440];
  int _epoch=0;
  @override
  void initState(){super.initState();unawaited(_load());}
  @override
  void dispose(){++_epoch;_offsets.clear();super.dispose();}
  Future<void> _load() async {
    final serial=++_epoch;
    setState((){_loading=true;_error=null;});
    try{
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null)throw StateError('Signed out');
      final p=await _repo.reminderPreferences();
      if(!mounted||serial!=_epoch||
          await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      setState((){
        _owner=owner;_enabled=p.enabled;_allowed=p.allowedOffsets;
        _offsets..clear()..addAll(p.offsets);_loading=false;
      });
    }catch(_){
      if(mounted&&serial==_epoch)setState((){
        _owner=null;_loading=false;_error='Reminder options are unavailable. Retry.';
      });
    }
  }
  String _label(int minutes)=>switch(minutes){
    0=>'At start time',
    15=>'15 minutes before',
    60=>'1 hour before',
    1440=>'1 day before',
    _=>minutes.toString()+' minutes before',
  };
  Future<void> _save() async {
    if(_saving||_owner==null)return;
    setState((){_saving=true;_error=null;});
    try{
      final confirmed=await _repo.saveReminderPreferences(
        enabled:_enabled,offsets:_offsets.toList()..sort());
      if(!mounted||await OrbitIdentityClient.instance.currentLocalSocialOwner()!=_owner)return;
      setState((){
        _enabled=confirmed.enabled;_offsets..clear()..addAll(confirmed.offsets);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Plan reminder preferences saved.')));
    }catch(_){
      if(mounted)setState(()=>_error='Could not save reminder settings. Retry.');
    }finally{if(mounted)setState(()=>_saving=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:650),
      child:Padding(padding:const EdgeInsets.fromLTRB(20,20,20,12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const AppScreenHeader(title:'Plan Reminders',prominent:true),
          const SizedBox(height:16),
          Expanded(child:_loading?const Center(child:CircularProgressIndicator(
            color:AppColors.primaryEnd))
          :_owner==null?Center(child:Column(
            mainAxisSize:MainAxisSize.min,children:[
              Text(_error??'Reminder options unavailable.',
                style:AppTypography.bodyMuted),
              TextButton(onPressed:()=>unawaited(_load()),child:const Text('Retry')),
            ]))
          :ListView(children:[
            Container(decoration:BoxDecoration(color:Colors.white,
              borderRadius:BorderRadius.circular(20)),
              child:SwitchListTile.adaptive(
                title:Text('Plan reminders',style:AppTypography.body),
                subtitle:Text('Get reminders for Plans you organize or join.',
                  style:AppTypography.bodyMuted),
                activeTrackColor:AppColors.primaryEnd,
                value:_enabled,onChanged:(x)=>setState(()=>_enabled=x))),
            const SizedBox(height:20),
            Text('When to remind me',style:AppTypography.smallHeading),
            const SizedBox(height:10),
            for(final minutes in _allowed)
              Container(margin:const EdgeInsets.only(bottom:10),
                decoration:BoxDecoration(color:Colors.white,
                  borderRadius:BorderRadius.circular(15)),
                child:CheckboxListTile(
                  title:Text(_label(minutes),style:AppTypography.body),
                  value:_offsets.contains(minutes),
                  activeColor:AppColors.primaryEnd,
                  onChanged:!_enabled?null:(value)=>setState((){
                    if(value==true){_offsets.add(minutes);}
                    else{_offsets.remove(minutes);}
                  }))),
            const SizedBox(height:12),
            Text('In-app reminders work without push notifications. Device push requires separate approval.',
              style:AppTypography.bodyMuted),
          ])),
          if(_error!=null&&_owner!=null)Text(_error!,
            style:AppTypography.body.copyWith(color:Colors.red)),
          const SizedBox(height:12),
          if(_owner!=null)AppPrimaryButton(label:_saving?'Saving…':'Save',
            enabled:!_saving,onPressed:()=>unawaited(_save())),
        ]),
      ),
    ))),
  );
}
