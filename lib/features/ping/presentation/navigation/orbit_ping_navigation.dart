import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../widgets/orbit_ping_feedback.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../../circles/data/orbit_circle_repository.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../../location/data/orbit_location_repository.dart';
import '../../../location/presentation/orbit_location_share_sheet.dart';
import '../../data/orbit_ping_repository.dart';
import '../../data/orbit_ping_notification_preferences.dart';
import '../screens/ping_screen.dart';

/// Reuses the already-approved PingScreen and full-width Circle bottom sheet.
/// No new visual language, new dialog framework or duplicate Ping screen.
abstract final class OrbitPingNavigation {
  static void _notify(BuildContext context,String message) {
    if(!context.mounted)return;
    OrbitPingFeedback.show(context,message);
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
            if(state==OrbitPingSendState.accepted) {
              // Cache only a server-accepted recipient for offline chooser.
              try {await pings.rememberRecipient(OrbitPingRecipient(
                id:recipientId,name:recipientName,
                contextType:contextType,contextId:circleId));}catch(_){}
              try {
                if(await OrbitPingNotificationPreferences.instance.hapticsEnabled()){
                  await HapticFeedback.lightImpact();
                }
              }catch(_){} // Never fail sending due to an unavailable haptic.
            }
            _notify(pageContext,state==OrbitPingSendState.accepted
              ? 'Ping accepted. Waiting for recipient confirmation.'
              : 'Ping queued. Retry from Sent Pings when connected.');
          }catch(error){
            rethrow; // Composer displays a Failed state and retry.
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
      // Offline chooser is restricted to already accepted recipients. Their
      // current eligibility is always rechecked on the server at replay.
      try {
        final recent=await (repository??OrbitPingRepository()).recentRecipients();
        members.addAll(recent.where((r)=>r.contextType=='friend')
          .map((r)=>OrbitPerson(id:r.id,name:r.name,username:'')));
      }catch(_){}
      if(members.isEmpty) {
        _notify(context,'Friends unavailable. Connect once to load an authorized recipient.');
        return;
      }
      _notify(context,'Showing previously contacted friends. Permissions are checked on send.');
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
      // No arbitrary offline Circle member selection. Only previous accepted
      // recipients are locally known and every retry rechecks Circle access.
      List<OrbitPingRecipient> recent=const [];
      try { recent=await (repository??OrbitPingRepository()).recentRecipients(); }
      catch (_) {}
      final known=recent.where((r)=>r.contextType=='circle'&&r.contextId!=null).toList();
      if(known.isEmpty) {
        _notify(context,'Circles unavailable. Reconnect to choose a Circle member.');
        return;
      }
      if(!context.mounted)return;
      _notify(context,'Showing previously contacted Circle members. Access is checked on send.');
      final person=await showOrbitCircleSheet<OrbitPingRecipient>(
        context:context,title:'Recent Circle members',
        builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,
          children:known.map((r)=>OrbitCircleSheetAction(
            title:r.name,icon:Icons.person_outline_rounded,
            onTap:()=>Navigator.of(sheet).pop(r))).toList()),
      );
      if(person!=null&&context.mounted) {
        await openPerson(context,recipientId:person.id,
          recipientName:person.name,contextType:'circle',
          circleId:person.contextId,repository:repository);
      }
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
    OrbitPingPage? page;
    List<OrbitPingPending> pending=const [];
    try {
      pending=await pings.pending();
      page=await pings.page('outbox');
    } catch (_) {
      // Authenticated local pending intents can still be reviewed offline.
      try {pending=await pings.pending();}catch(_){}
    }
    if(!context.mounted)return;
    await showOrbitCircleSheet<void>(
      context:context,title:'Sent Pings',
      builder:(sheet)=>Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          if(pending.isNotEmpty) ...[
            OrbitCircleSheetAction(
              title:'Retry pending Pings ('+pending.length.toString()+')',
              icon:Icons.refresh_rounded,
              onTap:() async {
                Navigator.of(sheet).pop();
                try {await pings.retryPending();}
                catch (_) {/* Keep pending state unless server denies it. */}
                if(context.mounted)await showSent(context,repository:pings);
              },
            ),
            const SizedBox(height:10),
            ...pending.map((intent)=>OrbitCircleSheetAction(
              title:'Queued · '+(intent.type=='custom'
                ? (intent.customText??'Custom Ping') : intent.type),
              icon:Icons.schedule_rounded,
              onTap:()=>Navigator.of(sheet).pop(),
            )),
          ],
          if(page==null && pending.isEmpty)
            const Text('Sent Pings cannot be loaded. Reconnect to refresh.'),
          if(page!=null && page.items.isEmpty && pending.isEmpty)
            const Text('No sent Pings yet.'),
          if(page!=null)...page.items.map((ping){
            final status=ping.respondedAt!=null?'Hey acknowledged'
              : ping.status=='seen'?'Seen'
              : ping.status=='delivered'?'Delivered'
              : 'Accepted · awaiting delivery';
            return OrbitCircleSheetAction(
              title:ping.displayText+' · '+status,
              icon:ping.respondedAt!=null?Icons.waving_hand_outlined
                :ping.status=='seen'?Icons.done_all_rounded
                :ping.status=='delivered'?Icons.done_rounded
                :Icons.schedule_rounded,
              onTap:()=>Navigator.of(sheet).pop(),
            );
          }),
        ],
      ),
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
      // Circle members need not also be friends. Resolve a sender name only
      // through the recipient's currently authorized Circle roster.
      if(ping.contextType=='circle' && ping.contextId!=null) {
        try {
          final circles=OrbitCircleRepository();
          for(var pageNumber=1;pageNumber<=10;pageNumber++) {
            final page=await circles.members(ping.contextId!,page:pageNumber);
            for(final member in page.items) {
              if(member.id==ping.senderId){sender=member.name;break;}
            }
            if(sender!='Orbit member'||!page.hasMore)break;
          }
        }catch(_){/* Never reveal an unauthorized Circle or roster. */}
      }
    }
    if(!context.mounted)return;
    final sheetFuture=showOrbitCircleSheet<String>(
      context:context,title:'Incoming Ping',
      builder:(sheet)=>Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Padding(padding:const EdgeInsets.only(bottom:14),
            child:Row(children:[
              CircleAvatar(radius:24,backgroundColor:const Color(0xFFEFECFF),
                child:Text(sender.trim().split(RegExp(r'\s+')).where(
                  (part)=>part.isNotEmpty).take(2)
                  .map((part)=>part.substring(0,1).toUpperCase()).join(),
                  style:const TextStyle(color:AppColors.primaryEnd,fontWeight:FontWeight.w700))),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(sender,maxLines:2,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontWeight:FontWeight.w600)),
                  const SizedBox(height:4),Text(ping.displayText),
                ])),
            ])),
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
    // A confirmed rendered frame is delivery evidence; a fetched server row
    // alone is not. Seen is distinct and only follows closing this sheet.
    await WidgetsBinding.instance.endOfFrame;
    if(context.mounted) {
      try {
        if(await OrbitPingNotificationPreferences.instance.hapticsEnabled()){
          await HapticFeedback.mediumImpact();
        }
      }catch(_){} // Never block the recipient receipt.
      try{await pings.receipt(ping.id,'delivered');}catch(_){}
    }
    final action=await sheetFuture;
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
      final replyId=const Uuid().v4();
      try{
        await pings.replyHey(ping.id,clientId:replyId);
        _notify(context,'Acknowledgement sent.');
      }catch(_){
        if(context.mounted) {
          OrbitPingFeedback.show(context,'Acknowledgement not confirmed.',
            onRetry:(){
              pings.replyHey(ping.id,clientId:replyId).then((_){
                _notify(context,'Acknowledgement sent.');
              }).catchError((_){
                _notify(context,'Acknowledgement could not be confirmed.');
              });
            });
        }
      }
    }
  }
}
