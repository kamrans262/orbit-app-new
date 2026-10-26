import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../data/orbit_moment_repository.dart';
import 'orbit_live_moment_viewer.dart';

/// Opt-in, currently authorized HTTPS notices, never fabricated FCM delivery.
/// Uses the standard Orbit header and white background without public counts.
class OrbitLiveMomentNotificationsScreen extends StatefulWidget {
  const OrbitLiveMomentNotificationsScreen({super.key});
  @override
  State<OrbitLiveMomentNotificationsScreen> createState() =>
    _OrbitLiveMomentNotificationsScreenState();
}

class _OrbitLiveMomentNotificationsScreenState
    extends State<OrbitLiveMomentNotificationsScreen> {
  final _repository=OrbitMomentRepository();
  List<Map<String,dynamic>> _items=const [];
  bool _loading=true;
  String? _error;

  @override
  void initState(){super.initState();unawaited(_load());}

  Future<void> _load() async {
    if(mounted)setState((){_loading=true;_error=null;});
    try{
      final rows=await _repository.notifications();
      if(mounted)setState((){
        _items=rows;
        _loading=false;
      });
    }catch(_){
      if(mounted)setState((){
        _items=const [];
        _loading=false;
        _error='Moment notices are unavailable. Retry when connected.';
      });
    }
  }

  Future<void> _configureMute() async {
    try {
      final options=await _repository.audienceOptions();
      final current=await _repository.mutedCircleNotifications();
      if(!mounted)return;
      final edited=<String>{...current};
      bool busy=false;
      await showModalBottomSheet<void>(context:context,
        backgroundColor:AppColors.background,useSafeArea:true,
        isScrollControlled:true,
        shape:const RoundedRectangleBorder(
          borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
        builder:(sheet)=>StatefulBuilder(builder:(sheet,update)=>Padding(
          padding:const EdgeInsets.fromLTRB(20,20,20,24),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Mute Circle Moments',style:AppTypography.smallHeading),
            const SizedBox(height:8),
            Text('Muting a Circle stops its Moment notifications; it does not change who may see Moments.',
              style:AppTypography.bodyMuted),
            const SizedBox(height:14),
            if(options.circles.isEmpty)
              Text('No active Circles',style:AppTypography.bodyMuted),
            ConstrainedBox(constraints:const BoxConstraints(maxHeight:300),
              child:ListView(shrinkWrap:true,children:[
                for(final circle in options.circles)
                  SwitchListTile(
                    title:Text(circle.name,style:AppTypography.body),
                    value:edited.contains(circle.id),
                    activeColor:AppColors.primaryEnd,
                    onChanged:busy?null:(value)=>update((){
                      if(value)edited.add(circle.id);
                      else edited.remove(circle.id);
                    }),
                  ),
              ])),
            const SizedBox(height:14),
            AppPrimaryButton(label:busy?'Saving…':'Save preferences',
              onPressed:() async {
                if(busy)return;
                update(()=>busy=true);
                try{
                  for(final circle in options.circles){
                    final was=current.contains(circle.id);
                    final now=edited.contains(circle.id);
                    if(was!=now)await _repository.setCircleNotificationMute(circle.id,now);
                  }
                  if(sheet.mounted)Navigator.of(sheet).pop();
                  if(mounted)unawaited(_load());
                }catch(_){
                  if(mounted)ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content:Text('Could not save Circle notification settings.')));
                }finally{
                  if(sheet.mounted)update(()=>busy=false);
                }
              }),
          ]),
        )),
      );
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Circle notification settings are unavailable.')));
    }
  }

  Future<void> _open(Map<String,dynamic> row) async {
    final id=row['moment_id'],context=row['context_id'],notice=row['id'];
    if(id is! String||context is! String||notice is! String)return;
    try{
      // Validate access immediately before opening a notification.
      final item=await _repository.notificationMoment(id,context);
      final author=await _repository.name(item.creatorId);
      await _repository.markNotificationRead(notice);
      if(!mounted)return;
      await Navigator.of(this.context).push<void>(MaterialPageRoute(
        builder:(_)=>OrbitLiveMomentViewer(moment:item,
          repository:_repository,author:author)));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content:Text('This private Moment is no longer available.')));
    }
    if(mounted)unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:20),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const SizedBox(height:20),
        Row(children:[
          const Expanded(child:AppScreenHeader(
            title:'Moment notifications',prominent:true)),
          AppCircularIconButton(
            semanticLabel:'Mute Circle notifications',
            onPressed:()=>unawaited(_configureMute()),
            icon:Icons.notifications_off_outlined,
            iconSize:20,size:40,
            iconGradient:AppColors.primaryGradient),
        ]),
        const SizedBox(height:18),
        Expanded(child:_loading
          ? const Center(child:CircularProgressIndicator(color:AppColors.primaryEnd))
          : _error!=null
            ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(_error!,style:AppTypography.bodyMuted,
                textAlign:TextAlign.center),
              TextButton(onPressed:()=>unawaited(_load()),
                child:const Text('Try again')),
            ]))
            : _items.isEmpty
              ? Center(child:Text('No Moment notifications',
                  style:AppTypography.bodyMuted))
              : RefreshIndicator(
                  onRefresh:_load,
                  child:ListView.separated(
                    itemCount:_items.length,
                    separatorBuilder:(_,index)=>const Divider(height:1),
                    itemBuilder:(context,index) {
                      final row=_items[index];
                      return ListTile(
                        contentPadding:const EdgeInsets.symmetric(vertical:5),
                        leading:Icon(row['read']==true
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_outlined,
                          color:AppColors.primaryEnd),
                        title:Text('Private Moment available',
                          style:AppTypography.body),
                        subtitle:Text('Tap to view if you still have access',
                          style:AppTypography.bodyMuted),
                        trailing:const Icon(Icons.chevron_right_rounded),
                        onTap:()=>unawaited(_open(row)),
                      );
                    },
                  ),
                )),
      ]),
    )),
  );
}
