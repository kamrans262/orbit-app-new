import 'package:flutter/material.dart';

import '../../circles/presentation/widgets/orbit_circle_confirmation.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../friends/data/orbit_social_repository.dart';
import '../data/orbit_messaging_api.dart';
import '../data/orbit_messaging_models.dart';
import '../data/orbit_messaging_coordinator.dart';
import '../../../core/widgets/app_primary_button.dart';

/// Optional explicit report evidence; never collected from messages automatically.
typedef OrbitReportableMessage=({String id,String text});

/// Reuses Orbit's full-width white sheets, current action rows and popup
/// confirmation. Reports do not share private message content by default.
class OrbitMessagingConversationActions {
  const OrbitMessagingConversationActions({
    OrbitMessagingApi? api,OrbitSocialRepository? social,
    OrbitMessagingCoordinator? coordinator,
  }):_api=api,_social=social,_coordinator=coordinator;
  final OrbitMessagingApi? _api;
  final OrbitSocialRepository? _social;
  final OrbitMessagingCoordinator? _coordinator;
  OrbitMessagingApi get api=>_api??OrbitMessagingApi();
  OrbitSocialRepository get social=>_social??OrbitSocialRepository();
  OrbitMessagingCoordinator get coordinator=>_coordinator??
    OrbitMessagingCoordinator(api:api);

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

  /// A full fingerprint must be compared over an independent trusted
  /// channel (in person, voice, etc.). Mere server delivery is not proof of
  /// the other person's new device identity.
  Future<void> _confirmPeerKey(BuildContext context,String peer,
      OrbitMessagingRemoteDevice device) async {
    if(!context.mounted)return;
    final input=TextEditingController();
    try{
      final approved=await showOrbitCircleSheet<bool>(
        context:context,title:'Verify Device Encryption',
        builder:(sheet)=>Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            const Text('Compare this complete safety fingerprint with '
              'your contact using a separate trusted method. '
              'A changed fingerprint could indicate a new device or '
              'an attempt to intercept private messages.'),
            const SizedBox(height:12),
            SelectableText(device.fingerprint),
            const SizedBox(height:12),
            TextField(controller:input,
              autocorrect:false,enableSuggestions:false,
              decoration:const InputDecoration(
                labelText:'Enter the independently verified fingerprint')),
            const SizedBox(height:16),
            AppPrimaryButton(label:'Trust Verified Device',onPressed:(){
              if(input.text.trim().toLowerCase()!=device.fingerprint){
                ScaffoldMessenger.maybeOf(sheet)?.showSnackBar(
                  const SnackBar(content:Text(
                    'Safety fingerprint does not match.')));
                return;
              }
              Navigator.of(sheet).pop(true);
            }),
            const SizedBox(height:8),
            TextButton(onPressed:()=>Navigator.of(sheet).pop(false),
              child:const Text('Cancel')),
          ],
        ));
      if(approved!=true||!context.mounted)return;
      await coordinator.acceptVerifiedPeerIdentity(
        peerId:peer,deviceId:device.id,
        verifiedFingerprint:device.fingerprint);
      _notice(context,'Verified contact keys updated. Reopen this chat '
        'to establish new encrypted sessions.');
    }catch(_){
      _notice(context,'The device identity was not changed. '
        'Recheck the safety fingerprint and trusted device settings.');
    }finally{
      input.dispose();
    }
  }

  Future<void> _reviewPeerKeys(BuildContext context,String peer) async {
    try{
      final directory=await api.discoverKeys(peer,
        consumeOneTimePrekey:false);
      if(!context.mounted)return;
      await showOrbitCircleSheet<void>(
        context:context,title:'Encryption Safety',
        builder:(sheet)=>Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            const Text('Review the identity of each approved device. '
              'Only trust a changed identity after comparing the full '
              'fingerprint with your contact.'),
            const SizedBox(height:12),
            ...directory.devices.map((device)=>Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:OrbitCircleSheetAction(
                title:'Verify device '+device.id.substring(
                  0,device.id.length>8?8:device.id.length),
                icon:Icons.verified_user_outlined,onTap:() async {
                  Navigator.of(sheet).pop();
                  await _confirmPeerKey(context,peer,device);
                }),
            )),
          ],
        ));
    }catch(_){
      _notice(context,'Device verification could not be opened. '
        'Reconnect and confirm your friendship settings.');
    }
  }

  Future<void> openDirect(BuildContext context,{
    required OrbitConversation thread,required String peerId,
    required VoidCallback onClose,bool showEncryptionReview=false,
    List<OrbitReportableMessage> evidenceCandidates=const []}) async {
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
        if(showEncryptionReview)...[
          const SizedBox(height:10),
          OrbitCircleSheetAction(title:'Verify encryption devices',
            icon:Icons.verified_user_outlined,
            onTap:(){
              Navigator.of(sheet).pop();
              _reviewPeerKeys(context,peerId);
            }),
        ],
        const SizedBox(height:10),
        OrbitCircleSheetAction(title:'Report this conversation',
          icon:Icons.flag_outlined,
          onTap:(){
            Navigator.of(sheet).pop();
            _report(context,thread,evidenceCandidates);
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
    required OrbitConversation thread,required VoidCallback onClose,
    List<OrbitReportableMessage> evidenceCandidates=const []}) async{
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
            _report(context,thread,evidenceCandidates);
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

  /// Default report contains only a reason. A specific, already accepted
  /// message's plaintext is shared only after two explicit selections.
  Future<void> _report(BuildContext context,OrbitConversation thread,
      List<OrbitReportableMessage> evidenceCandidates) async{
    if(!context.mounted)return;
    const reasons=<String,String>{
      'spam':'Spam','abuse':'Abuse','harassment':'Harassment',
      'impersonation':'Impersonation','other':'Other',
    };
    final eligible=evidenceCandidates.where((message)=>
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(message.id) &&
      message.text.trim().isNotEmpty && message.text.length<=600
    ).take(15).toList(growable:false);
    await showOrbitCircleSheet<void>(context:context,
      title:'Report Conversation',builder:(sheet)=>Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const Text('Select a reason. Private message content is never '
            'shared by default. You can separately select one message '
            'and explicitly approve sharing its exact text.'),
          const SizedBox(height:12),
          ...reasons.entries.map((entry)=>Padding(
            padding:const EdgeInsets.only(bottom:10),
            child:OrbitCircleSheetAction(title:entry.value,
              icon:Icons.flag_outlined,onTap:(){
                Navigator.of(sheet).pop();
                _reportDetails(context,thread,entry.key,entry.value,eligible);
              }),
          )),
        ],
      ));
  }

  Future<void> _reportDetails(BuildContext context,OrbitConversation thread,
      String reason,String label,
      List<OrbitReportableMessage> eligible) async{
    if(!context.mounted)return;
    await showOrbitCircleSheet<void>(context:context,
      title:'Report Details',builder:(sheet)=>Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const Text('Report without sharing message content, or choose '
            'one specific message. Evidence is optional.'),
          const SizedBox(height:12),
          OrbitCircleSheetAction(
            title:'Report without message evidence',
            icon:Icons.lock_outline,onTap:(){
              Navigator.of(sheet).pop();
              _submitReport(context,thread,reason,label);
            }),
          if(eligible.isNotEmpty)...[
            const SizedBox(height:16),
            const Text('Optional: select a message to share'),
            const SizedBox(height:10),
            ...eligible.map((message)=>Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:OrbitCircleSheetAction(
                title:message.text.length>65
                  ?'${message.text.substring(0,65)}…':message.text,
                icon:Icons.chat_bubble_outline,onTap:(){
                  Navigator.of(sheet).pop();
                  _submitReport(context,thread,reason,label,selected:message);
                },
              ),
            )),
          ],
        ],
      ));
  }

  Future<void> _submitReport(BuildContext context,OrbitConversation thread,
      String reason,String label,{OrbitReportableMessage? selected}) async{
    if(!context.mounted)return;
    final hasEvidence=selected!=null;
    final description=hasEvidence
      ?'Share this exact decrypted message with authorized moderators '
        'as evidence?\n\n"${selected.text}"\n\n'
        'This choice cannot be undone.'
      :'Send this ${label.toLowerCase()} report with only the reason and '
        'routing metadata? No private message content will be shared.';
    if(!await _confirm(context,hasEvidence?'Share Message Evidence?':
        'Submit Report?',description,
        hasEvidence?'Share and Report':'Submit Report'))return;
    if(!context.mounted)return;
    await _mutate(context,() async{
      await api.report(thread.id,reason:reason,message:selected?.id,
        sharedEvidence:selected?.text,confirmed:hasEvidence);
    },'Your report was submitted.');
  }
}
