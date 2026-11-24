import '../../../realtime/presentation/orbit_realtime_refresh.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:orbit_ui/core/widgets/app_gradient_action_label.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../data/orbit_sos_repository.dart';
import 'orbit_live_sos_incident_screen.dart';

/// User-owned private SOS history and responder inbox. Never use offline
/// history as a permission grant for emergency locations or actions.
class OrbitLiveSosInboxScreen extends StatefulWidget {
  const OrbitLiveSosInboxScreen({this.repository,super.key});
  final OrbitSosRepository? repository;
  @override
  State<OrbitLiveSosInboxScreen> createState()=>_OrbitLiveSosInboxScreenState();
}
class _OrbitLiveSosInboxScreenState extends State<OrbitLiveSosInboxScreen>
    with WidgetsBindingObserver {
  late final OrbitSosRepository _repo=widget.repository??OrbitSosRepository();
  List<OrbitSosIncident> _items=[];
  bool _loading=true;
  String? _error;
  int _epoch=0;
  OrbitRealtimeRefresh? _m25Refresh;
  @override
  void initState(){super.initState();
    _m25Refresh=OrbitRealtimeRefresh(modules:const {'sos'},visible:()=>OrbitRealtimeRefresh.current(this),refresh:()=>_reload(),fallback:true)..start();
WidgetsBinding.instance.addObserver(this);unawaited(_reload());}
  @override
  void dispose(){
    _m25Refresh?.dispose();
++_epoch;WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(_reload());
    if(state==AppLifecycleState.paused || state==AppLifecycleState.hidden){
      ++_epoch;
      if(mounted)setState((){_items=[];_loading=true;});
    }
  }
  Future<void> _reload() async {
    final call=++_epoch;
    if(mounted)setState((){_loading=true;_error=null;_items=[];});
    try {
      final data=await _repo.incidents();
      if(mounted && call==_epoch)setState((){_items=data;_loading=false;});
    }catch(_){
      if(mounted && call==_epoch)setState((){
        _loading=false;_error='SOS alerts could not be verified. Reconnect and retry.';});
    }
  }
  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>OrbitLiveSosIncidentScreen(incidentId:id,repository:_repo)));
    if(mounted)unawaited(_reload());
  }
  /// Exactly the list treatment from the approved Notifications inbox:
  /// existing header, typography, dividers and ListTile. No custom cards.
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(20,20,20,12),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const AppScreenHeader(title:'SOS Alerts',prominent:true),
          const SizedBox(height:18),
          Text(
            'Only server-registered SOS incidents appear here. '
            'Orbit does not automatically contact emergency services.',
            style:AppTypography.bodyMuted,
          ),
          const SizedBox(height:12),
          Expanded(
            child:_loading
              ?const Center(child:CircularProgressIndicator(
                  color:AppColors.primaryEnd))
              :_error!=null
                ?Center(child:Column(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      Text(_error!,textAlign:TextAlign.center,
                        style:AppTypography.bodyMuted),
                      TextButton(onPressed:()=>unawaited(_reload()),
                        child:const AppGradientActionLabel('Try again')),
                    ],
                  ))
                :_items.isEmpty
                  ?Center(child:Text('No verified SOS alerts.',
                      style:AppTypography.bodyMuted))
                  :RefreshIndicator(
                      onRefresh:_reload,
                      child:ListView.separated(
                        physics:const AlwaysScrollableScrollPhysics(),
                        itemCount:_items.length,
                        separatorBuilder:(_,__)=>const Divider(height:1),
                        itemBuilder:(context,index){
                          final incident=_items[index];
                          final title=incident.role=='responder'
                            ?'SOS from ${incident.initiatorName}'
                            :'Your SOS';
                          return ListTile(
                            key:ValueKey('sos-incident-${incident.id}'),
                            contentPadding:const EdgeInsets.symmetric(vertical:5),
                            leading:const Icon(Icons.sos_rounded,
                              color:AppColors.primaryEnd),
                            title:Text(title,style:AppTypography.body,
                              maxLines:2,overflow:TextOverflow.ellipsis),
                            subtitle:Text(
                              '${incident.status} · ${incident.deliveryDescription}',
                              style:AppTypography.bodyMuted,
                              maxLines:3,overflow:TextOverflow.ellipsis),
                            trailing:const Icon(Icons.chevron_right_rounded),
                            onTap:()=>unawaited(_open(incident.id)),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    )),
  );
}
