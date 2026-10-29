import 'package:flutter/material.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../../circles/data/orbit_circle_repository.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../../location/data/orbit_location_repository.dart';
import '../../../location/presentation/orbit_location_share_sheet.dart';
import '../../data/orbit_ping_repository.dart';
import '../screens/ping_screen.dart';

/// Reuses the already-approved PingScreen and full-width Circle bottom sheet.
/// No new visual language, new dialog framework or duplicate Ping screen.
abstract final class OrbitPingNavigation {
  static void _notify(BuildContext context,String message) {
    if(!context.mounted)return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content:Text(message)));
  }

  static Future<void> openPerson(BuildContext context,{
    required String recipientId,
    required String recipientName,
    String contextType='friend',
    String? circleId,
    OrbitPingRepository? repository,
  }) async {
    final pings=repository??OrbitPingRepository();
    try{
      if(!await pings.available()){
        _notify(context,'Ping is not available yet. No data was shared.');
        return;
      }
    }on OrbitIdentityException catch(error){
      if(error.statusCode!=null ||
          await OrbitIdentityClient.instance.currentLocalSocialOwner()==null){
        _notify(context,'Ping service is unavailable. Please try again.');
        return;
      }
      // Transport is offline, not a server denial: allow composing a Ping
      // to a previously authorized person and queue the stable client ID.
    }catch(_){
      _notify(context,'Ping service is unavailable. Please try again.');
      return;
    }
    if(!context.mounted)return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(pageContext)=>PingScreen.demo(
        recipientOrCircleId:recipientId,recipientName:recipientName,
        onSendPing:(submission) async {
          try{
            final state=await pings.send(
              recipientId:recipientId,type:submission.type,
              contextType:contextType,contextId:circleId,
              customText:submission.type=='custom'?submission.message:null);
            _notify(pageContext,state==OrbitPingSendState.accepted
              ? 'Ping accepted. Waiting for recipient confirmation.'
              : 'Ping saved securely. It will retry when you reconnect.');
          }catch(_){
            _notify(pageContext,'Ping could not be sent. Check recipient permissions.');
          }
        },
      ),
    ));
  }

  static Future<void> chooseFriend(BuildContext context,{
    OrbitSocialRepository? social,OrbitPingRepository? repository,
  }) async {
    final friends=social??OrbitSocialRepository();
    final members=<OrbitPerson>[];
    try{
      for(var page=1;page<=10;page++){
        final result=await friends.friends(page:page);
        members.addAll(result.items);
        if(!result.hasMore)break;
      }
    }catch(_){
      _notify(context,'Friends could not be loaded. Please reconnect.');
      return;
    }
    if(!context.mounted)return;
    final choice=await showOrbitCircleSheet<Object>(
      context:context,title:'Choose a friend to Ping',
      builder:(sheet)=>Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          OrbitCircleSheetAction(
            title:'Circle members',icon:Icons.groups_outlined,
            onTap:()=>Navigator.of(sheet).pop('circles'),
          ),
          const SizedBox(height:10),
          OrbitCircleSheetAction(
            title:'Sent Pings',icon:Icons.outbox_outlined,
            onTap:()=>Navigator.of(sheet).pop('outbox'),
          ),
          const SizedBox(height:10),
          if(members.isEmpty)
            const Padding(padding:EdgeInsets.symmetric(vertical:18),
              child:Text('No friends available. A person must allow Pings before receiving one.'))
          else
            ...members.map((person)=>OrbitCircleSheetAction(
              title:person.name,icon:Icons.person_outline_rounded,
              onTap:()=>Navigator.of(sheet).pop(person),
            )),
        ],
      ),
    );
    if(!context.mounted)return;
    if(choice=='outbox'){
      await showSent(context,repository:repository);
    }else if(choice=='circles'){
      await chooseCircleMember(context,repository:repository);
    }else if(choice is OrbitPerson){
      await openPerson(context,recipientId:choice.id,
        recipientName:choice.name,repository:repository);
    }
  }

  static Future<void> chooseCircleMember(BuildContext context,
      {OrbitPingRepository? repository}) async {
    final circles=OrbitCircleRepository();
    final collection=<OrbitCircle>[];
    try{
      for(var n=1;n<=10;n++){
        final page=await circles.list(page:n);
        collection.addAll(page.items);
        if(!page.hasMore)break;
      }
    }catch(_){
      _notify(context,'Circles could not be loaded. Please reconnect.');
      return;
    }
    if(!context.mounted)return;
    final selected=await showOrbitCircleSheet<OrbitCircle>(
      context:context,title:'Choose a Circle',
      builder:(sheet)=>collection.isEmpty
        ? const Text('No active Circles available.')
        : Column(mainAxisSize:MainAxisSize.min,
            children:collection.map((circle)=>OrbitCircleSheetAction(
              title:circle.name,icon:Icons.groups_outlined,
              onTap:()=>Navigator.of(sheet).pop(circle),
            )).toList()),
    );
    if(selected==null||!context.mounted)return;
    final members=<OrbitCircleMember>[];
    try{
      final me=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      for(var n=1;n<=10;n++){
        final page=await circles.members(selected.id,page:n);
        members.addAll(page.items.where((member)=>member.id!=me &&
          member.role!='restricted'));
        if(!page.hasMore)break;
      }
    }catch(_){
      _notify(context,'Circle members are unavailable. Please reconnect.');
      return;
    }
    if(!context.mounted)return;
    final recipient=await showOrbitCircleSheet<OrbitCircleMember>(
      context:context,title:'Choose a Circle member',
      builder:(sheet)=>members.isEmpty
        ? const Text('No eligible members available.')
        : Column(mainAxisSize:MainAxisSize.min,
            children:members.map((member)=>OrbitCircleSheetAction(
              title:member.name,icon:Icons.person_outline_rounded,
              onTap:()=>Navigator.of(sheet).pop(member),
            )).toList()),
    );
    if(recipient==null||!context.mounted)return;
    await openPerson(context,recipientId:recipient.id,
      recipientName:recipient.name,contextType:'circle',
      circleId:selected.id,repository:repository);
  }

  static Future<void> showSent(BuildContext context,
      {OrbitPingRepository? repository}) async {
    final pings=repository??OrbitPingRepository();
    OrbitPingPage page;
    try{
      page=await pings.page('outbox');
    }catch(_){
      _notify(context,'Sent Pings could not be loaded. Please reconnect.');
      return;
    }
    if(!context.mounted)return;
    await showOrbitCircleSheet<void>(
      context:context,title:'Sent Pings',
      builder:(sheet)=>page.items.isEmpty
        ? const Text('No sent Pings yet.')
        : Column(mainAxisSize:MainAxisSize.min,
            children:page.items.map((ping) {
              final status=ping.status=='seen'?'Seen'
                : ping.status=='delivered'?'Delivered'
                : 'Accepted · awaiting delivery';
              return OrbitCircleSheetAction(
                title:ping.displayText+' · '+status,
                icon:ping.status=='seen'?Icons.done_all_rounded
                  :ping.status=='delivered'?Icons.done_rounded
                  :Icons.schedule_rounded,
                onTap:()=>Navigator.of(sheet).pop(),
              );
            }).toList()),
    );
  }

  static Future<void> showIncoming(BuildContext context,OrbitPingRecord ping,
      {OrbitPingRepository? repository}) async {
    final pings=repository??OrbitPingRepository();
    if(!context.mounted)return;
    String sender='Orbit member';
    try {
      final person=await OrbitSocialRepository().preview(ping.senderId)
        .timeout(const Duration(seconds:4));
      sender=person.name;
    } catch (_) {
      // Never reveal a blocked or private profile.
    }
    if(!context.mounted)return;
    final action=await showOrbitCircleSheet<String>(
      context:context,title:'Incoming Ping',
      builder:(sheet)=>Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Padding(padding:const EdgeInsets.only(bottom:14),
            child:Text('From: '+sender+'\n'+ping.displayText)),
          OrbitCircleSheetAction(
            title:'👋 Hey',icon:Icons.waving_hand_outlined,
            onTap:()=>Navigator.of(sheet).pop('hey'),
          ),
          const SizedBox(height:10),
          OrbitCircleSheetAction(
            title:'📍 Share Location',icon:Icons.location_on_outlined,
            onTap:()=>Navigator.of(sheet).pop('location'),
          ),
          const SizedBox(height:10),
          OrbitCircleSheetAction(
            title:'Close',icon:Icons.close_rounded,
            onTap:()=>Navigator.of(sheet).pop('close'),
          ),
        ],
      ),
    );
    // A visible, dismissed sheet is a real Seen event, unlike a fetched row.
    if(context.mounted) {
      try{await pings.receipt(ping.id,'seen');}catch(_){}
    }
    if(action=='location'&&context.mounted) {
      // Reuse the existing explicit-consent location sheet; never transmit
      // coordinates from the Ping itself or skip device permission checks.
      try {
        final location=OrbitLocationRepository();
        final capability=await location.capabilities();
        if(context.mounted) {
          await showOrbitLocationShareSheet(context:context,
            repository:location,capabilities:capability);
        }
      } catch (_) {
        _notify(context,'Location sharing is unavailable. No location was shared.');
      }
    }
    if(action=='hey'&&context.mounted){
      try{
        await pings.replyHey(ping.id);
        _notify(context,'Acknowledgement sent.');
      }catch(_){
        _notify(context,'Could not send acknowledgement. Please try again.');
      }
    }
  }
}
