import 'package:flutter/material.dart';

import '../../circles/presentation/widgets/orbit_circle_confirmation.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../friends/data/orbit_social_repository.dart';
import '../data/orbit_messaging_api.dart';
import '../data/orbit_messaging_models.dart';

/// Reuses Orbit's full-width white sheets, current action rows and popup
/// confirmation. Reports do not share private message content by default.
class OrbitMessagingConversationActions {
  const OrbitMessagingConversationActions({
    OrbitMessagingApi? api,OrbitSocialRepository? social,
  }):_api=api,_social=social;
  final OrbitMessagingApi? _api;
  final OrbitSocialRepository? _social;
  OrbitMessagingApi get api=>_api??OrbitMessagingApi();
  OrbitSocialRepository get social=>_social??OrbitSocialRepository();

  void _notice(BuildContext context,String message){
    if(context.mounted){
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content:Text(message)));
    }
  }
  Future<void> _mutate(BuildContext context,
      Future<void> Function() action,String success) async {
    try{
      await action();
      _notice(context,success);
    }catch(_){
      _notice(context,'Action could not be completed. Reconnect and retry.');
    }
  }
  Future<bool> _confirm(BuildContext context,String title,String description,
      String confirmLabel,{bool destructive=false}) async {
    if(!context.mounted)return false;
    return showOrbitCircleConfirmation(context:context,title:title,
      description:description,confirmLabel:confirmLabel,
      cancelLabel:'Cancel',destructive:destructive);
  }

  Future<void> openDirect(BuildContext context,{
    required OrbitConversation thread,required String peerId,
    required VoidCallback onClose}) async {
    if(thread.kind!='direct'||thread.peerId!=peerId)return;
    await showOrbitCircleSheet<void>(context:context,
      title:'Conversation Options',
      builder:(sheet)=>Column(children:[
        OrbitCircleSheetAction(title:'Mute notifications',
          icon:Icons.notifications_off_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _mutate(context,() async{
              await api.preferences(thread.id,mute:true);
            },'Conversation notifications muted.');
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Unmute notifications',
          icon:Icons.notifications_active_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _mutate(context,() async{
              await api.preferences(thread.id,mute:false);
            },'Conversation notifications enabled.');
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Report this conversation',
          icon:Icons.flag_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _report(context,thread);
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Archive conversation',
          icon:Icons.archive_outlined,
          onTap:() async{
            Navigator.of(sheet).pop();
            if(!await _confirm(context,'Archive this conversation?',
              'Remove this conversation from your messages list. '
              'Messages remain encrypted.','Archive'))return;
            if(!context.mounted)return;
            await _mutate(context,() async{
              await api.preferences(thread.id,archive:true);
              if(context.mounted)onClose();
            },'Conversation archived.');
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Block this person',
          icon:Icons.block_rounded,destructive:true,
          onTap:() async {
            Navigator.of(sheet).pop();
            if(!await _confirm(context,'Block this person?',
              'Blocking stops future direct messaging and applies '
              'your existing privacy rules.','Block Person',
              destructive:true))return;
            if(!context.mounted)return;
            await _mutate(context,() async{
              await social.block(peerId);
              if(context.mounted)onClose();
            },'Person blocked.');
          }),
      ]));
  }

  Future<void> openCircle(BuildContext context,{
    required OrbitConversation thread,required VoidCallback onClose}) async{
    if(thread.kind!='circle')return;
    await showOrbitCircleSheet<void>(context:context,
      title:'Circle Chat Options',
      builder:(sheet)=>Column(children:[
        OrbitCircleSheetAction(title:'Mute Circle messages',
          icon:Icons.notifications_off_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _mutate(context,() async{
              await api.preferences(thread.id,mute:true);
            },'Circle messages muted.');
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Unmute Circle messages',
          icon:Icons.notifications_active_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _mutate(context,() async{
              await api.preferences(thread.id,mute:false);
            },'Circle messages unmuted.');
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Report this Circle chat',
          icon:Icons.flag_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _report(context,thread);
          }),
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Leave this Circle',
          icon:Icons.logout_rounded,destructive:true,
          onTap:() async{
            Navigator.of(sheet).pop();
            if(!await _confirm(context,'Leave this Circle?',
              'Leaving this chat also leaves the Circle and revokes '
              'your future access to its protected conversations.',
              'Leave Circle',destructive:true))return;
            if(!context.mounted)return;
            await _mutate(context,() async{
              await api.leave(thread.id);
              if(context.mounted)onClose();
            },'You have left this Circle.');
          }),
      ]));
  }

  Future<void> _report(BuildContext context,OrbitConversation thread) async{
    if(!context.mounted)return;
    const reasons=<String,String>{
      'spam':'Spam','abuse':'Abuse','harassment':'Harassment',
      'impersonation':'Impersonation','other':'Other',
    };
    await showOrbitCircleSheet<void>(context:context,
      title:'Report Conversation',builder:(sheet)=>Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const Text('Select a reason. The report contains routing metadata '
            'and your selected reason only; no decrypted message content '
            'is shared without separate, explicit consent.'),
          const SizedBox(height:12),
          ...reasons.entries.map((entry)=>Padding(
            padding:const EdgeInsets.only(bottom:10),
            child:OrbitCircleSheetAction(title:entry.value,
              icon:Icons.flag_outlined,onTap:() async{
                Navigator.of(sheet).pop();
                if(!await _confirm(context,'Submit Report?',
                  'Send this '+entry.value.toLowerCase()+
                  ' report without sharing private message content?',
                  'Submit Report'))return;
                if(!context.mounted)return;
                await _mutate(context,() async{
                  await api.report(thread.id,reason:entry.key);
                },'Your report was submitted.');
              }),
          )),
        ],
      ));
  }
}
