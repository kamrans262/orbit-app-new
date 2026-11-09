import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../circles/data/orbit_circle_repository.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../data/orbit_plan_repository.dart';
import '../../domain/orbit_plan_models.dart';

/// Uses the approved Orbit field/button vocabulary. Client id is retained
/// across explicit retries of the same submission; no duplicate creation.
class OrbitLivePlanEditorScreen extends StatefulWidget {
  const OrbitLivePlanEditorScreen({super.key,this.planId,this.repository});
  final String? planId;
  final OrbitPlanRepository? repository;
  @override
  State<OrbitLivePlanEditorScreen> createState()=>_OrbitLivePlanEditorScreenState();
}
class _OrbitLivePlanEditorScreenState extends State<OrbitLivePlanEditorScreen> {
  late final OrbitPlanRepository _repo=widget.repository??OrbitPlanRepository();
  final _form=GlobalKey<FormState>();
  final _title=TextEditingController();
  final _description=TextEditingController();
  final _location=TextEditingController();
  final _friends=<OrbitPerson>[];
  final _circles=<OrbitCircle>[];
  final _selectedPeople=<String>{};
  final _selectedCircles=<String>{};
  String _clientId=const Uuid().v4();
  String? _error,_owner;
  OrbitPlan? _original;
  late DateTime _start=DateTime.now().add(const Duration(days:1));
  DateTime? _end;
  bool _loading=true,_saving=false,_frozen=false;
  int _epoch=0;
  bool get _editing=>widget.planId!=null;
  @override
  void initState(){super.initState();unawaited(_load());}
  @override
  void dispose(){
    ++_epoch;
    _title.dispose();_description.dispose();_location.dispose();
    _selectedPeople.clear();_selectedCircles.clear();
    super.dispose();
  }
  Future<void> _load() async {
    final serial=++_epoch;
    setState((){_loading=true;_error=null;});
    try {
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null)throw StateError('Sign in required');
      final futures=await Future.wait<dynamic>([
        OrbitSocialRepository().friends(),
        OrbitCircleRepository().list(),
        if(_editing)_repo.detail(widget.planId!),
      ]);
      if(!mounted||serial!=_epoch||
         await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      final friends=futures[0] as OrbitFriendPage<OrbitPerson>;
      final circles=futures[1] as OrbitCirclePage<OrbitCircle>;
      final plan=_editing?futures[2] as OrbitPlan:null;
      if(_editing && (plan==null||!plan.canEdit))throw StateError('Read only');
      setState((){
        _owner=owner;
        _friends..clear()..addAll(friends.items);
        _circles..clear()..addAll(circles.items.where((c)=>
          c.lifecycleState=='active' || c.lifecycleState=='permanent'));
        _original=plan;
        if(plan!=null){
          _title.text=plan.title;_description.text=plan.description;
          _location.text=plan.placeLabel??'';
          _start=plan.startsAt;_end=plan.endsAt;
        }
        _loading=false;
      });
    }catch(_){
      if(mounted&&serial==_epoch)setState((){
        _loading=false;
        _error='Plan form could not be verified. Please reconnect and reopen.';
      });
    }
  }

  Future<void> _pickStart() async {
    final now=DateTime.now();
    final initial=_start.isBefore(now)?now:_start;
    final date=await showDatePicker(context:context,
      initialDate:initial,firstDate:DateTime(now.year,now.month,now.day),
      lastDate:DateTime(now.year+5));
    if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,
      initialTime:TimeOfDay.fromDateTime(_start));
    if(time==null||!mounted)return;
    setState((){
      _start=DateTime(date.year,date.month,date.day,time.hour,time.minute);
      if(_end!=null && !_end!.isAfter(_start))_end=null;
    });
  }
  Future<void> _pickEnd() async {
    final date=await showDatePicker(context:context,
      initialDate:_end??_start,firstDate:_start,
      lastDate:DateTime(_start.year+5));
    if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,
      initialTime:TimeOfDay.fromDateTime(_end??_start.add(const Duration(hours:1))));
    if(time==null||!mounted)return;
    final selected=DateTime(date.year,date.month,date.day,time.hour,time.minute);
    if(!selected.isAfter(_start)){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('End must be after start.')));
      return;
    }
    setState(()=>_end=selected);
  }
  String _label(DateTime value)=>
    MaterialLocalizations.of(context).formatMediumDate(value)+' · '+
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value));

  Future<bool> _review() async {
    final result=await showModalBottomSheet<bool>(context:context,
      isScrollControlled:true,backgroundColor:AppColors.background,
      showDragHandle:true,builder:(sheet)=>SafeArea(child:Padding(
        padding:const EdgeInsets.fromLTRB(20,10,20,22),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(_editing?'Review changes':'Review Plan',style:AppTypography.smallHeading),
            const SizedBox(height:14),
            Text(_title.text.trim(),style:AppTypography.body),
            const SizedBox(height:8),
            Text(_label(_start),style:AppTypography.bodyMuted),
            if(_end!=null)Text('Ends '+_label(_end!),style:AppTypography.bodyMuted),
            if(_location.text.trim().isNotEmpty)
              Text(_location.text.trim(),style:AppTypography.bodyMuted),
            const SizedBox(height:8),
            Text('Additional people: '+_selectedPeople.length.toString()+
              ' · Circles: '+_selectedCircles.length.toString(),
              style:AppTypography.bodyMuted),
            const SizedBox(height:8),
            Text('Invitations are delivered only when current privacy and Circle permissions permit.',
              style:AppTypography.bodyMuted),
            const SizedBox(height:20),
            AppPrimaryButton(label:_editing?'Save changes':'Create Plan',
              onPressed:()=>Navigator.of(sheet).pop(true)),
          ]))));
    return result==true;
  }
  Future<void> _submit() async {
    if(_saving||_loading||_owner==null)return;
    if(!_frozen && !(_form.currentState?.validate()??false))return;
    if(!_frozen && (!_start.isAfter(DateTime.now())||
        (_end!=null && !_end!.isAfter(_start)))){
      setState(()=>_error='Choose a future start, and an end after the start.');
      return;
    }
    if(!_frozen && !await _review())return;
    if(!mounted)return;
    setState((){_saving=true;_frozen=true;_error=null;});
    try{
      final owner=_owner!;
      final plan=_editing
        ?await _repo.update(widget.planId!,revision:_original!.revision,
          title:_title.text,description:_description.text,
          startsAt:_start,endsAt:_end,placeLabel:_location.text,
          inviteeIds:_selectedPeople.toList(),circleIds:_selectedCircles.toList())
        :await _repo.create(clientId:_clientId,title:_title.text,
          description:_description.text,startsAt:_start,endsAt:_end,
          placeLabel:_location.text,inviteeIds:_selectedPeople.toList(),
          circleIds:_selectedCircles.toList());
      if(!mounted||await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      Navigator.of(context).pop(plan.id);
    }catch(e){
      if(mounted)setState((){
        _error=e is OrbitIdentityException && e.statusCode==409
          ?'This Plan changed. Reopen it to review the latest revision.'
          :'Submission not confirmed. Retry the same request to prevent duplicates.';
      });
    }finally{if(mounted)setState(()=>_saving=false);}
  }

  InputDecoration _inputDecoration(String label)=>InputDecoration(
    labelText:label,filled:true,fillColor:Colors.white,
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)));
  Widget _field(String label,TextEditingController controller,{
      int lines=1,int max=160,bool required=false})=Padding(
    padding:const EdgeInsets.only(bottom:14),
    child:TextFormField(controller:controller,maxLines:lines,maxLength:max,
      style:AppTypography.body,decoration:_inputDecoration(label),
      validator:required?(v)=>(v??'').trim().isEmpty?'Required':null:null));

  @override
  Widget build(BuildContext context) {
    final ready=!_loading && _owner!=null;
    return Scaffold(backgroundColor:AppColors.background,
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:650),
        child:Padding(padding:const EdgeInsets.fromLTRB(20,20,20,12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          AppScreenHeader(title:_editing?'Edit Plan':'Create Plan',prominent:true),
          const SizedBox(height:16),
          Expanded(child:_loading?const Center(child:CircularProgressIndicator(
              color:AppColors.primaryEnd))
          :!ready?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(_error??'Plan unavailable.',style:AppTypography.bodyMuted),
              TextButton(onPressed:()=>unawaited(_load()),child:const Text('Retry')),
            ]))
          :Form(key:_form,child:AbsorbPointer(absorbing:_saving||_frozen,
            child:ListView(children:[
              _field('Title',_title,required:true,max:120),
              _field('Description',_description,max:4000,lines:3),
              _field('Location / meeting place',_location,max:160),
              ListTile(contentPadding:EdgeInsets.zero,
                leading:const Icon(Icons.event_outlined,color:AppColors.primaryEnd),
                title:Text('Starts',style:AppTypography.bodyMuted),
                subtitle:Text(_label(_start),style:AppTypography.body),
                trailing:const Icon(Icons.chevron_right_rounded),
                onTap:()=>unawaited(_pickStart())),
              ListTile(contentPadding:EdgeInsets.zero,
                leading:const Icon(Icons.event_available_outlined,
                    color:AppColors.primaryEnd),
                title:Text('Ends (optional)',style:AppTypography.bodyMuted),
                subtitle:Text(_end==null?'Not set':_label(_end!),
                    style:AppTypography.body),
                trailing:IconButton(icon:Icon(_end==null
                  ?Icons.chevron_right_rounded:Icons.close_rounded),
                  onPressed:()=>_end==null?unawaited(_pickEnd()):setState(()=>_end=null)),
                onTap:()=>unawaited(_pickEnd())),
              const SizedBox(height:12),
              Text(_editing?'Invite more friends':'Invite friends',
                style:AppTypography.smallHeading),
              const SizedBox(height:6),
              if(_friends.isEmpty)
                Text('No eligible friends loaded.',style:AppTypography.bodyMuted),
              for(final person in _friends)
                CheckboxListTile(
                  title:Text(person.name,style:AppTypography.body),
                  value:_selectedPeople.contains(person.id),
                  activeColor:AppColors.primaryEnd,
                  onChanged:(on)=>setState((){
                    if(on==true){_selectedPeople.add(person.id);}
                    else{_selectedPeople.remove(person.id);}
                  })),
              const SizedBox(height:12),
              Text('Invite Circles',style:AppTypography.smallHeading),
              Text('Recipients must satisfy current Circle consent and privacy rules.',
                style:AppTypography.bodyMuted),
              for(final circle in _circles)
                CheckboxListTile(title:Text(circle.name,style:AppTypography.body),
                  value:_selectedCircles.contains(circle.id),
                  activeColor:AppColors.primaryEnd,
                  onChanged:(on)=>setState((){
                    if(on==true){_selectedCircles.add(circle.id);}
                    else{_selectedCircles.remove(circle.id);}
                  })),
              const SizedBox(height:20),
            ]))),
          ),
          if(_error!=null&&ready)Padding(
            padding:const EdgeInsets.only(top:10),
            child:Text(_error!,style:AppTypography.body.copyWith(color:Colors.red))),
          const SizedBox(height:10),
          if(ready)AppPrimaryButton(
            label:_saving?'Submitting…':_frozen?'Retry same submission':
              _editing?'Review changes':'Review & Create',
            enabled:!_saving,onPressed:()=>unawaited(_submit())),
          if(_frozen && !_saving)
            TextButton(onPressed:()=>Navigator.of(context).pop(),
              child:const Text('Close without retrying')),
        ]))),
      )))
    );
  }
}
