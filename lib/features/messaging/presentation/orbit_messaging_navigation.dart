import 'package:flutter/material.dart';

import '../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../data/orbit_messaging_api.dart';
import 'orbit_live_direct_chat_screen.dart';
import 'orbit_live_group_chat_screen.dart';
import 'orbit_live_messages_screen.dart';

/// Uses Orbit transitions, sheets and the three existing approved screens.
abstract final class OrbitMessagingNavigation {
  static void _notice(BuildContext context,String message){
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(message)));
  }

  static Future<void> openList(BuildContext context) async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>const OrbitLiveMessagesScreen()));
  }

  static Future<void> openDirect(BuildContext context,{
    required String peerId,required String peerName}) async {
    if(peerId.isEmpty)return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveDirectChatScreen(
        peerId:peerId,peerName:peerName)));
  }

  static Future<void> openCircle(BuildContext context,{
    required String circleId,required String circleName,
    OrbitMessagingApi? messaging}) async {
    final api=messaging??OrbitMessagingApi();
    try{
      final status=await api.consent(circleId);
      if(!context.mounted)return;
      if(status['enabled']!=true){
        final accepted=await showOrbitCircleSheet<bool>(
          context:context,title:'Circle Messaging Permission',
          builder:(sheet)=>Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              const Text('Allow encrypted messages with this Circle? '
                'Current membership, your global Privacy Settings and '
                'each other member’s consent still apply. You can revoke '
                'this permission from the Circle later.'),
              const SizedBox(height:18),
              AppPrimaryButton(label:'Allow Circle Messaging',
                onPressed:()=>Navigator.of(sheet).pop(true)),
              const SizedBox(height:8),
              TextButton(onPressed:()=>Navigator.of(sheet).pop(false),
                child:const Text('Not now')),
            ]),
        );
        if(accepted!=true||!context.mounted)return;
        await api.setConsent(circleId,true);
      }
      if(!context.mounted)return;
      await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
        builder:(_)=>OrbitLiveGroupChatScreen(
          circleId:circleId,circleName:circleName)));
    }catch(_){
      _notice(context,'Circle messaging is unavailable. '
        'Check membership, individual consent and global Privacy Settings.');
    }
  }
}
