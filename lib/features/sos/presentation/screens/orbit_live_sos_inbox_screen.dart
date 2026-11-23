import 'dart:async';

import 'package:flutter/material.dart';

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
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_reload());}
  @override
  void dispose(){++_epoch;WidgetsBinding.instance.removeObserver(this);super.dispose();}
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
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,
    body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,20,20,16),child:
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const AppScreenHeader(title:'SOS Alerts',prominent:true),
        const SizedBox(height:16),
        Text('Only server-registered SOS incidents appear here. An alert in Orbit does not mean emergency services were contacted.',
          style:AppTypography.body.copyWith(color:AppColors.textSecondary,fontSize:12)),
        const SizedBox(height:12),
        Expanded(child:_loading?const Center(child:CircularProgressIndicator())
          :_error!=null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(_error!,textAlign:TextAlign.center),TextButton(onPressed:_reload,child:const Text('Retry')),
          ])):_items.isEmpty?const Center(child:Text('No verified SOS alerts.')):
          RefreshIndicator(onRefresh:_reload,child:ListView.separated(
            itemCount:_items.length,separatorBuilder:(_,__)=>const SizedBox(height:10),
            itemBuilder:(context,index){
              final item=_items[index];
              return Material(color:Colors.white,borderRadius:BorderRadius.circular(14),child:
                ListTile(key:ValueKey('sos-incident-${item.id}'),
                  leading:Icon(Icons.sos_rounded,color:item.status=='active'
                    ?const Color(0xFFE84040):AppColors.textSecondary),
                  title:Text(item.role=='responder'?'SOS from an Orbit contact':'Your SOS',
                    style:AppTypography.body.copyWith(fontWeight:FontWeight.w600)),
                  subtitle:Text('${item.status} · ${item.deliveryDescription}',
                    maxLines:3,overflow:TextOverflow.ellipsis),
                  trailing:const Icon(Icons.chevron_right_rounded),
                  onTap:()=>_open(item.id),
                ));
            },
          ))),
      ]))),
  );
}
