import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/upcoming_plan_card.dart';
import '../../data/orbit_plan_repository.dart';
import '../../domain/orbit_plan_models.dart';

/// Dedicated list reuses the approved Home Plan card without demo members.
class OrbitLivePlansScreen extends StatefulWidget {
  const OrbitLivePlansScreen({super.key,this.repository});
  final OrbitPlanRepository? repository;
  @override
  State<OrbitLivePlansScreen> createState()=>_OrbitLivePlansScreenState();
}
class _OrbitLivePlansScreenState extends State<OrbitLivePlansScreen>
    with WidgetsBindingObserver {
  late final OrbitPlanRepository _repo=widget.repository??OrbitPlanRepository();
  final _items=<OrbitPlan>[];
  String _tab='upcoming';
  String? _cursor,_error,_owner;
  bool _loading=true,_loadingMore=false,_offline=false;
  int _epoch=0;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_load());}
  @override
  void dispose(){++_epoch;_items.clear();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(_load());
    if(state==AppLifecycleState.paused||state==AppLifecycleState.hidden) {
      ++_epoch;
      if(mounted)setState((){_items.clear();_cursor=null;_owner=null;});
    }
  }
  Future<void> _load() async {
    final serial=++_epoch;
    if(mounted)setState((){_loading=true;_error=null;_offline=false;
      _items.clear();_cursor=null;});
    String? owner;
    try {
      owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null)throw StateError('Sign in required');
      final result=await _repo.list(tab:_tab);
      if(!mounted||serial!=_epoch ||
          await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      setState((){_items..clear()..addAll(result.items);_cursor=result.nextCursor;
        _owner=owner;_loading=false;});
    }catch(e) {
      if(!mounted||serial!=_epoch)return;
      if(owner!=null && OrbitPlanRepository.temporaryOffline(e)){
        try{
          final page=await _repo.lastVerifiedList(_tab);
          if(page!=null && mounted && serial==_epoch &&
              await OrbitIdentityClient.instance.currentLocalSocialOwner()==owner){
            setState((){
              _items..clear()..addAll(page.items);
              _cursor=null;_owner=owner;_loading=false;_offline=true;
            });
            return;
          }
        }catch(_){}
      }
      if(e is OrbitIdentityException &&
          const {401,403,404}.contains(e.statusCode)){
        try{await _repo.clearCachedPlans();}catch(_){}
      }
      if(mounted&&serial==_epoch)setState((){
        _loading=false;_offline=false;
        _error='Plans could not be verified. Reconnect and retry.';
        _items.clear();_cursor=null;_owner=null;
      });
    }
  }
  Future<void> _more() async {
    if(_cursor==null||_loadingMore||_loading||_owner==null)return;
    _loadingMore=true;
    final owner=_owner!,cursor=_cursor!,tab=_tab,serial=_epoch;
    try {
      final page=await _repo.list(tab:tab,cursor:cursor);
      if(!mounted||serial!=_epoch || _tab!=tab ||
          await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      final ids=_items.map((e)=>e.id).toSet();
      setState((){_items.addAll(page.items.where((e)=>ids.add(e.id)));
        _cursor=page.nextCursor;_error=null;});
    }catch(_) {
      if(mounted&&serial==_epoch)setState(()=>_error='Could not load more Plans.');
    }finally{_loadingMore=false;}
  }
  Future<void> _open(String id) async {
    await Navigator.of(context).pushNamed(AppRoutes.planDetail,arguments:id);
    if(mounted)unawaited(_load());
  }
  Future<void> _create() async {
    await Navigator.of(context).pushNamed(AppRoutes.planCreate);
    if(mounted)unawaited(_load());
  }
  String _schedule(OrbitPlan p) {
    final d=p.startsAt.toLocal();
    final date=MaterialLocalizations.of(context).formatMediumDate(d);
    final time=MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(d));
    return '$date · $time';
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:650),
      child:Padding(padding:const EdgeInsets.fromLTRB(20,20,20,12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Expanded(child:AppScreenHeader(title:'Plans',prominent:true)),
            IconButton(
              tooltip:'Plan reminder settings',
              icon:const Icon(Icons.notifications_active_outlined,
                color:AppColors.primaryEnd),
              onPressed:()=>Navigator.of(context).pushNamed(AppRoutes.planReminders),
            ),
          ]),
          const SizedBox(height:18),
          Row(children:[
            for(final tab in const ['upcoming','past'])...[
              Expanded(child:ChoiceChip(
                label:Center(child:Text(tab=='upcoming'?'Upcoming':'Past')),
                selected:_tab==tab,
                selectedColor:const Color(0xFFF0E8FF),
                labelStyle:AppTypography.body.copyWith(
                  color:_tab==tab?AppColors.primaryEnd:AppColors.textPrimary,
                  fontWeight:FontWeight.w600),
                onSelected:(_){if(_tab!=tab){setState(()=>_tab=tab);unawaited(_load());}},
              )),
              if(tab=='upcoming')const SizedBox(width:10),
            ],
          ]),
          const SizedBox(height:16),
          if(_offline)Padding(padding:const EdgeInsets.only(bottom:12),
            child:Text('Offline — last verified Plans, read-only. Refresh to check access.',
              style:AppTypography.bodyMuted)),
          Expanded(child:_loading
            ?const Center(child:CircularProgressIndicator(color:AppColors.primaryEnd))
            :_error!=null&&_items.isEmpty
              ?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Text(_error!,style:AppTypography.bodyMuted,textAlign:TextAlign.center),
                  TextButton(onPressed:()=>unawaited(_load()),child:const Text('Retry')),
                ]))
              :RefreshIndicator(onRefresh:_load,child:ListView.separated(
                physics:const AlwaysScrollableScrollPhysics(),
                itemCount:_items.length+(_cursor!=null?1:0),
                separatorBuilder:(_,__)=>const SizedBox(height:10),
                itemBuilder:(_,index){
                  if(index==_items.length) return TextButton(
                    onPressed:_loadingMore?null:()=>unawaited(_more()),
                    child:Text(_loadingMore?'Loading…':'Load more'));
                  final p=_items[index];
                  return UpcomingPlanCard(
                    key:ValueKey('plan_'+p.id),
                    data:UpcomingPlanData(id:p.id,title:p.title,schedule:_schedule(p),
                      location:p.placeLabel,participants:const <ParticipantData>[]),
                    onTap:()=>unawaited(_open(p.id)));
                },
              ))),
          if(!_loading&&_items.isEmpty&&_error==null)
            Padding(padding:const EdgeInsets.only(top:12),
              child:Text('No '+_tab+' plans yet.',style:AppTypography.bodyMuted)),
          const SizedBox(height:12),
          AppPrimaryButton(label:'Create Plan',
            enabled:!_offline,onPressed:()=>unawaited(_create())),
        ]),
      ),
    ))),
  );
}
