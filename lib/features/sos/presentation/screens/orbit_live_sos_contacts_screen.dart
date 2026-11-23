import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../data/orbit_sos_repository.dart';

/// Reuses approved Orbit list, buttons and Circle selection sheet.
/// Contact assignment requires the other person's explicit acceptance.
class OrbitLiveSosContactsScreen extends StatefulWidget {
  const OrbitLiveSosContactsScreen({this.repository,this.social,super.key});
  final OrbitSosRepository? repository;
  final OrbitSocialRepository? social;
  @override
  State<OrbitLiveSosContactsScreen> createState()=>_OrbitLiveSosContactsScreenState();
}
class _OrbitLiveSosContactsScreenState extends State<OrbitLiveSosContactsScreen> {
  late final OrbitSosRepository _repo=widget.repository??OrbitSosRepository();
  late final OrbitSocialRepository _social=widget.social??OrbitSocialRepository();
  List<OrbitSosContact> _contacts=[];
  Map<String,String> _friendNames={};
  String? _owner,_error;
  bool _loading=true,_busy=false;
  int _epoch=0;
  @override
  void initState(){super.initState();unawaited(_load());}
  @override
  void dispose(){++_epoch;super.dispose();}
  Future<void> _load() async {
    final call=++_epoch;
    if(mounted)setState((){_loading=true;_error=null;});
    try{
      final owner=await _repo.owner();
      final items=await _repo.contacts();
      final names=<String,String>{};
      try{
        for(var page=1;page<=10;page++){
          final friends=await _social.friends(page:page);
          for(final friend in friends.items)names[friend.id]=friend.name;
          if(!friends.hasMore)break;
        }
      }catch(_){
        // Never infer a display name from a UUID or a stale offline roster.
      }
      if(mounted&&call==_epoch&&await _repo.owner()==owner)setState((){
        _contacts=items;_friendNames=names;_owner=owner;_loading=false;});
    }catch(_){if(mounted&&call==_epoch)setState((){
      _contacts=[];_friendNames={};_loading=false;_error='Trusted contacts cannot be verified right now.';});}
  }
  Future<void> _mutate(Future<void> Function() work) async {
    if(_busy)return;
    setState(()=>_busy=true);
    try{await work();if(mounted)await _load();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('The SOS service did not confirm this change. Try again.')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _chooseFriend() async {
    if(_busy)return;
    final people=<OrbitPerson>[];
    try{
      for(var page=1;page<=10;page++){
        final result=await _social.friends(page:page);
        people.addAll(result.items);
        if(!result.hasMore)break;
      }
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('Connect to Orbit to verify available friends.')));return;}
    if(!mounted)return;
    final person=await showOrbitCircleSheet<OrbitPerson>(
      context:context,title:'Choose trusted contact',
      builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
        if(people.isEmpty)const Padding(padding:EdgeInsets.all(14),
          child:Text('No verified friends are available.')),
        for(final friend in people)OrbitCircleSheetAction(title:friend.name,
          icon:Icons.person_outline_rounded,
          onTap:()=>Navigator.of(sheet).pop(friend)),
      ]),
    );
    if(person==null||!mounted)return;
    await _mutate(() async{await _repo.addContact(person.id);});
  }
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,
    body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,20,20,16),child:
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const AppScreenHeader(title:'Emergency Contacts',prominent:true),
        const SizedBox(height:14),
        Text('A friend only becomes your trusted SOS contact after accepting your request.',
          style:AppTypography.body.copyWith(color:AppColors.textSecondary,fontSize:12)),
        const SizedBox(height:10),
        SizedBox(width:double.infinity,child:ElevatedButton.icon(
          onPressed:_busy?null:_chooseFriend,icon:const Icon(Icons.person_add_alt_1_outlined),
          label:const Text('Add trusted contact'))),
        const SizedBox(height:12),
        Expanded(child:_loading?const Center(child:CircularProgressIndicator())
          :_error!=null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text(_error!,textAlign:TextAlign.center),
              TextButton(onPressed:_load,child:const Text('Retry')),
            ])):_contacts.isEmpty?const Center(child:Text('No trusted contact requests yet.')):
            RefreshIndicator(onRefresh:_load,child:ListView.separated(
              itemCount:_contacts.length,separatorBuilder:(_,__)=>const SizedBox(height:10),
              itemBuilder:(context,index){
                final contact=_contacts[index];
                final outgoing=contact.ownerId==_owner;
                final personId=outgoing?contact.recipientId:contact.ownerId;
                final name=_friendNames[personId]??'Orbit contact';
                return Card(child:Padding(padding:const EdgeInsets.all(13),child:
                  Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(outgoing?name:'Request from $name',
                      style:AppTypography.body.copyWith(fontWeight:FontWeight.w600)),
                    Text('Status: ${contact.state}. ${outgoing?"Awaiting your friend’s choice":"Your consent is required"}.',
                      style:AppTypography.body.copyWith(fontSize:12)),
                    const SizedBox(height:8),
                    Wrap(spacing:8,children:[
                      if(!outgoing && contact.state=='requested')...[
                        TextButton(onPressed:_busy?null:()=>_mutate(() async{
                          await _repo.decideContact(contact.id,'accepted');}),
                          child:const Text('Accept')),
                        TextButton(onPressed:_busy?null:()=>_mutate(() async{
                          await _repo.decideContact(contact.id,'declined');}),
                          child:const Text('Decline')),
                      ],
                      TextButton(onPressed:_busy?null:()=>_mutate(() async{
                        await _repo.removeContact(contact.id);}),
                        child:const Text('Remove')),
                    ]),
                  ])));
              },
            ))),
      ]))),
  );
}
