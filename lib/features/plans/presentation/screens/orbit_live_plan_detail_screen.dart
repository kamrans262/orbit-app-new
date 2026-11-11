import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_plan_repository.dart';
import '../../domain/orbit_plan_models.dart';

class OrbitLivePlanDetailScreen extends StatefulWidget {
  const OrbitLivePlanDetailScreen({super.key,required this.planId,this.repository});
  final String planId;
  final OrbitPlanRepository? repository;
  @override
  State<OrbitLivePlanDetailScreen> createState()=>_OrbitLivePlanDetailScreenState();
}
class _OrbitLivePlanDetailScreenState extends State<OrbitLivePlanDetailScreen>
    with WidgetsBindingObserver {
  late final OrbitPlanRepository _repo=widget.repository??OrbitPlanRepository();
  OrbitPlan? _plan;
  bool _loading=true,_working=false,_offline=false;
  String? _error;
  int _epoch=0;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_load());}
  @override
  void dispose(){++_epoch;_plan=null;WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(_load());
    if(state==AppLifecycleState.paused||state==AppLifecycleState.hidden){
      ++_epoch;
      if(mounted)setState((){_plan=null;_loading=true;});
    }
  }
  Future<void> _load() async {
    final serial=++_epoch;
    setState((){_loading=true;_plan=null;_error=null;_offline=false;});
    String? owner;
    try{
      owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null)throw StateError('Signed out');
      final value=await _repo.detail(widget.planId);
      if(!mounted||serial!=_epoch||
          await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      setState((){_plan=value;_loading=false;});
    }catch(e){
      if(!mounted||serial!=_epoch)return;
      if(owner!=null && OrbitPlanRepository.temporaryOffline(e)){
        try{
          final cached=await _repo.lastVerifiedDetail(widget.planId);
          if(cached!=null && mounted && serial==_epoch &&
              await OrbitIdentityClient.instance.currentLocalSocialOwner()==owner){
            setState((){_plan=cached;_loading=false;_offline=true;});
            return;
          }
        }catch(_){}
      }
      if(e is OrbitIdentityException &&
          const {401,403,404}.contains(e.statusCode)){
        try{await _repo.clearCachedPlans();}catch(_){}
      }
      if(mounted&&serial==_epoch)setState((){
        _loading=false;_plan=null;_offline=false;
        _error='This Plan is unavailable or your access has changed.';
      });
    }
  }
  Future<void> _perform(Future<OrbitPlan> Function(OrbitPlan) work) async {
    final p=_plan;
    if(p==null||_working||_offline)return;
    setState(()=>_working=true);
    try{
      await work(p);
      if(mounted)await _load();
    }catch(_){
      if(mounted){
        setState(()=>_error='The action was not confirmed. Please refresh and retry.');
        await _load();
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Action not confirmed. Plan refreshed.')));
      }
    }finally{if(mounted)setState(()=>_working=false);}
  }
  Future<void> _edit() async {
    await Navigator.of(context).pushNamed(AppRoutes.planCreate,arguments:widget.planId);
    if(mounted)await _load();
  }
  Future<void> _cancel() async {
    final answer=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Cancel Plan?'),
      content:const Text('Invited friends will be informed, and future reminders will stop.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Keep Plan')),
        TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Cancel Plan')),
      ]));
    if(answer==true)await _perform((p)=>_repo.cancel(p.id,p.revision));
  }
  Future<void> _shareDirections(OrbitPlan p) async {
    // The location leaves Orbit only after an explicit user action.
    final destination=p.latitude!=null && p.longitude!=null
        ?p.latitude.toString()+','+p.longitude.toString()
        :(p.placeLabel??'').trim();
    if(destination.isEmpty)return;
    final link=Uri.https('www.google.com','/maps/dir/',{
      'api':'1','destination':destination,
    });
    try{
      await Share.share(link.toString(),subject:'Plan directions');
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Directions could not be shared.')));
    }
  }

  Widget _info(IconData icon,String title,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:9),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:AppColors.primaryEnd,size:20),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:AppTypography.bodyMuted),
        Text(value,style:AppTypography.body),
      ])),
    ]),
  );
  @override
  Widget build(BuildContext context){
    final p=_plan;
    return Scaffold(backgroundColor:AppColors.background,
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:650),
        child:Padding(padding:const EdgeInsets.fromLTRB(20,20,20,12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          const AppScreenHeader(title:'Plan Details',prominent:true),
          const SizedBox(height:18),
          Expanded(child:_loading?const Center(child:CircularProgressIndicator(
            color:AppColors.primaryEnd))
          :p==null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(_error??'Plan unavailable.',style:AppTypography.bodyMuted,
              textAlign:TextAlign.center),
            TextButton(onPressed:()=>unawaited(_load()),child:const Text('Retry')),
          ]))
          :RefreshIndicator(onRefresh:_load,child:ListView(children:[
            if(_offline)Padding(padding:const EdgeInsets.only(bottom:12),
              child:Text('Offline — last verified, read-only. Reconnect to confirm current permissions.',
                style:AppTypography.bodyMuted)),
            Container(padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(color:Colors.white,
                borderRadius:BorderRadius.circular(20)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(p.title,style:AppTypography.smallHeading),
                const SizedBox(height:8),
                Text(p.status=='cancelled'?'Cancelled':p.isUpcoming?'Upcoming':'Past',
                  style:AppTypography.bodyMuted),
                const SizedBox(height:12),
                _info(Icons.person_outline,'Organized by',p.organizerName),
                _info(Icons.schedule_outlined,'Date & time',
                  MaterialLocalizations.of(context).formatMediumDate(p.startsAt)+
                  ' · '+MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(p.startsAt))),
                if(p.endsAt!=null)_info(Icons.event_available_outlined,'Ends',
                  MaterialLocalizations.of(context).formatMediumDate(p.endsAt!)+
                  ' · '+MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(p.endsAt!))),
                if((p.placeLabel??'').isNotEmpty)_info(Icons.place_outlined,'Location',
                  p.placeLabel!),
                if((p.placeLabel??'').isNotEmpty ||
                    (p.latitude!=null && p.longitude!=null))
                  TextButton.icon(
                    onPressed:()=>unawaited(_shareDirections(p)),
                    icon:const Icon(Icons.directions_outlined),
                    label:const Text('Share directions link')),

                if(p.description.isNotEmpty)_info(Icons.notes_outlined,'Description',
                  p.description),
              ])),
            const SizedBox(height:16),
            Text('Participants',style:AppTypography.smallHeading),
            const SizedBox(height:10),
            if(p.participants.isEmpty)
              Text('No invited participants.',style:AppTypography.bodyMuted)
            else for(final person in p.participants)
              ListTile(contentPadding:EdgeInsets.zero,
                title:Text(person.name,style:AppTypography.body),
                subtitle:Text(person.state,style:AppTypography.bodyMuted),
                leading:const Icon(Icons.account_circle_outlined,
                  color:AppColors.primaryEnd)),
            const SizedBox(height:18),
            if(!_offline && p.canEdit) ...[
              AppPrimaryButton(label:'Edit Plan',onPressed:()=>unawaited(_edit())),
              TextButton(onPressed:_working?null:()=>unawaited(_cancel()),
                child:const Text('Cancel Plan')),
            ] else if(!_offline && p.canRespond) ...[
              if(p.myRsvp!='joined')
                AppPrimaryButton(label:'Join Plan',onPressed:()=>unawaited(
                  _perform((p)=>_repo.rsvp(p.id,'joined')))),
              if(p.myRsvp=='invited')
                TextButton(onPressed:_working?null:()=>unawaited(
                  _perform((p)=>_repo.rsvp(p.id,'declined'))),
                  child:const Text('Decline')),
              if(p.myRsvp=='joined')
                TextButton(onPressed:_working?null:()=>unawaited(
                  _perform((p)=>_repo.leave(p.id))),child:const Text('Leave Plan')),
              if(p.myRsvp=='declined')
                TextButton(onPressed:_working?null:()=>unawaited(
                  _perform((p)=>_repo.rsvp(p.id,'joined'))),
                  child:const Text('Change response to Join')),
            ],
            const SizedBox(height:20),
          ]))),
          if(_working)const LinearProgressIndicator(color:AppColors.primaryEnd),
        ]))),
      ))
    );
  }
}
