import 'dart:async';
import 'package:flutter/material.dart';
import 'package:orbit_ui/core/widgets/app_gradient_action_label.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
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
  /// The existing Circle sheet handles all contact actions. No new card,
  /// action menu, bottom-sheet system, or independent button styling.
  Future<void> _manageContact(OrbitSosContact contact,
      String displayName,bool outgoing) async {
    if(_busy || !mounted)return;
    final choice=await showOrbitCircleSheet<String>(
      context:context,title:displayName,
      builder:(sheet)=>Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Text(_contactStatus(contact,outgoing),
            style:AppTypography.bodyMuted),
          const SizedBox(height:16),
          if(!outgoing && contact.state=='requested') ...[
            OrbitCircleSheetAction(
              title:'Accept trusted contact',
              icon:Icons.check_circle_outline,
              onTap:()=>Navigator.of(sheet).pop('accepted'),
            ),
            const SizedBox(height:10),
            OrbitCircleSheetAction(
              title:'Decline request',
              icon:Icons.close_rounded,
              onTap:()=>Navigator.of(sheet).pop('declined'),
            ),
            const SizedBox(height:10),
          ],
          OrbitCircleSheetAction(
            title:'Remove trusted contact',
            icon:Icons.person_remove_outlined,
            destructive:true,
            onTap:()=>Navigator.of(sheet).pop('remove'),
          ),
        ],
      ),
    );
    if(choice==null || !mounted)return;
    if(choice=='remove') {
      final confirmed=await showOrbitPopupModal<bool>(
        context:context,
        builder:(dialog)=>OrbitPopupModal(
          title:'Remove trusted contact?',
          description:'This removes the SOS contact association. '
              'The person will no longer be an eligible trusted responder.',
          primaryAction:OrbitPopupDestructiveButton(
            label:'Remove',
            onPressed:()=>Navigator.of(dialog).pop(true),
          ),
          secondaryAction:OrbitPopupTextButton(
            label:'Cancel',
            onPressed:()=>Navigator.of(dialog).pop(false),
          ),
        ),
      );
      if(confirmed!=true || !mounted)return;
    }
    await _mutate(() async {
      if(choice=='accepted' || choice=='declined'){
        await _repo.decideContact(contact.id,choice);
      }else if(choice=='remove'){
        await _repo.removeContact(contact.id);
      }
    });
  }

  String _contactStatus(OrbitSosContact contact,bool outgoing) =>
    switch(contact.state){
      'accepted'=>'Accepted trusted SOS contact',
      'requested'=>outgoing
        ?'Request awaiting acceptance'
        :'Your consent is required',
      'declined'=>'Request declined',
      _=>'Contact status unavailable',
    };

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:650),
      child:Padding(
        padding:const EdgeInsets.fromLTRB(20,20,20,12),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const AppScreenHeader(title:'Emergency Contacts',prominent:true),
            const SizedBox(height:18),
            Text(
              'A friend becomes a trusted SOS contact only after accepting.',
              style:AppTypography.bodyMuted,
            ),
            const SizedBox(height:16),
            AppPrimaryButton(
              label:'Add trusted contact',
              enabled:!_busy,
              onPressed:()=>unawaited(_chooseFriend()),
            ),
            const SizedBox(height:18),
            Expanded(
              child:_loading
                ?const Center(child:CircularProgressIndicator(
                    color:AppColors.primaryEnd))
                :_error!=null
                  ?Center(child:Column(
                      mainAxisSize:MainAxisSize.min,
                      children:[
                        Text(_error!,style:AppTypography.bodyMuted,
                          textAlign:TextAlign.center),
                        TextButton(onPressed:()=>unawaited(_load()),
                          child:const AppGradientActionLabel('Try again')),
                      ],
                    ))
                  :_contacts.isEmpty
                    ?Center(child:Text('No trusted contact requests yet.',
                        style:AppTypography.bodyMuted))
                    :RefreshIndicator(
                        onRefresh:_load,
                        child:ListView.separated(
                          physics:const AlwaysScrollableScrollPhysics(),
                          itemCount:_contacts.length,
                          separatorBuilder:(_,__)=>const SizedBox(height:10),
                          itemBuilder:(context,index){
                            final contact=_contacts[index];
                            final outgoing=contact.ownerId==_owner;
                            final personId=outgoing
                              ?contact.recipientId:contact.ownerId;
                            final name=_friendNames[personId]??'Orbit contact';
                            return OrbitCircleSheetAction(
                              title:'$name · ${_contactStatus(contact,outgoing)}',
                              icon:Icons.person_outline_rounded,
                              onTap:()=>unawaited(_manageContact(
                                contact,name,outgoing)),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    ))),
  );
}
