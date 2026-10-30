import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../circles/data/orbit_circle_repository.dart';
import '../../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../../friends/data/orbit_social_repository.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_check_in_repository.dart';
import '../../domain/models/check_in_models.dart';
import '../screens/check_in_screen.dart';

/// Original CheckInScreen, Orbit sheets and native app navigation only.
/// HTTPS feeds are never cached: a tap always reauthorizes a record.
abstract final class OrbitCheckInNavigation {
  static void message(BuildContext context,String value){
    if(!context.mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(value)));
  }

  static Future<void> openComposer(BuildContext context,
      {OrbitCheckInRepository? repository}) async {
    final repo=repository??OrbitCheckInRepository();
    var sending=false;
    try {
      if(!await repo.available()){
        message(context,'Check-In is not available. No update was shared.');
        return;
      }
      // Foreground retries, not simulated push or background delivery.
      unawaited(repo.flushPending().catchError((Object _){ }));
    }on OrbitIdentityException catch(e){
      if(e.statusCode!=null){
        message(context,e.message);
        return;
      }
      // Network unavailable: only previously approved audience may be
      // reused for an offline draft, and the server reauthorizes on replay.
    }catch(_){
      message(context,'Unable to open Check-In right now.');
      return;
    }
    if(!context.mounted)return;
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(screen)=>CheckInScreen.demo(
        onCheckInSent:(submission) {
          if(sending)return;
          sending=true;
          unawaited(_submit(screen,repo,submission).whenComplete((){
            sending=false;
          }));
        },
        onViewHistory:()=>unawaited(showMine(screen,repository:repo)),
        onViewFeed:()=>unawaited(showFeed(screen,repository:repo)),
      ),
    ));
  }

  static Future<void> _submit(BuildContext context,OrbitCheckInRepository repo,
      CheckInSubmission submission) async {
    try{
      final scope=await chooseAudience(context,repo);
      if(scope==null||!context.mounted)return;
      final accepted=await showOrbitCircleSheet<bool>(
        context:context,title:'Review Check-In',
        builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(submission.customText??submission.activityName,
            style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
          const SizedBox(height:12),
          Text('Audience: '+scope.$1,
            style:const TextStyle(color:AppColors.textMuted)),
          const SizedBox(height:8),
          const Text('Only currently authorized people can view this update. '
            'Location is not attached.'),
          const SizedBox(height:18),
          AppPrimaryButton(label:'Publish Check-In',
            onPressed:()=>Navigator.of(sheet).pop(true)),
          const SizedBox(height:8),
          TextButton(onPressed:()=>Navigator.of(sheet).pop(false),
            child:const Text('Change or cancel')),
        ]),
      );
      if(accepted!=true||!context.mounted)return;
      final result=await repo.send(type:submission.activityId,
        text:submission.customText,audience:scope.$2);
      message(context,result==OrbitCheckInSendState.accepted
        ? 'Check-In published to your selected audience.'
        : 'Check-In saved securely. Retry when connected.');
    }catch(e){
      message(context,e is OrbitIdentityException?e.message:
        'Check-In could not be published. Nothing was shared.');
    }
  }

  /// Returns label and verified choice, never an implicit broad audience.
  static Future<(String,List<OrbitCheckInScope>)?> chooseAudience(
      BuildContext context,OrbitCheckInRepository repo) async {
    final choices=<(String,List<OrbitCheckInScope>)>[
      ('Only Me',const [OrbitCheckInScope.onlyMe]),
    ];
    String? note;
    try{
      final p=await repo.privacy();
      final visibility=p['activity_visibility'] as String? ?? 'Nobody';
      if(visibility=='Friends'){
        choices.add(('All Friends',const [OrbitCheckInScope.friends]));
        final social=OrbitSocialRepository();
        for(var page=1;page<=10;page++){
          final batch=await social.friends(page:page);
          for(final friend in batch.items){
            choices.add((friend.name,[OrbitCheckInScope('selected_friend',friend.id)]));
          }
          if(!batch.hasMore)break;
        }
      }else if(visibility=='My Circle'){
        final circles=OrbitCircleRepository();
        for(var page=1;page<=10;page++){
          final batch=await circles.list(page:page);
          for(final circle in batch.items){
            if(circle.lifecycleState=='active'){
              choices.add((circle.name,[OrbitCheckInScope('circle',circle.id)]));
            }
          }
          if(!batch.hasMore)break;
        }
      }else{
        note='Activity sharing is set to Nobody. Change it to Friends '
          'or My Circle in the existing Privacy Settings to share with others.';
      }
    }on OrbitIdentityException catch(e){
      if(e.statusCode!=null){
        message(context,e.message);
        return null;
      }
      note='Offline: only previously accepted audiences may be retried. '
        'Current permissions will be checked by the server.';
      final last=await repo.lastAudience();
      if(last.isNotEmpty){
        choices.add(('Previous audience (server will recheck)',last));
      }
    }catch(_){
      note='Unable to load people and Circle choices. Only Me is available.';
    }
    final friendChoices=choices.where((choice)=>choice.$2.length==1 &&
      choice.$2.first.type=='selected_friend').toList();
    final circleChoices=choices.where((choice)=>choice.$2.length==1 &&
      choice.$2.first.type=='circle').toList();
    if(friendChoices.length>1){
      choices.insert(2,('Choose multiple friends',const []));
    }
    if(circleChoices.length>1){
      choices.add(('Choose multiple Circles',const []));
    }
    if(!context.mounted)return null;
    final selected=await showOrbitCircleSheet<int>(
      context:context,title:'Choose Check-In audience',
      builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(note!=null) ...[
            Text(note,style:const TextStyle(color:AppColors.textMuted)),
            const SizedBox(height:12),
          ],
          for(var i=0;i<choices.length;i++)
            OrbitCircleSheetAction(title:choices[i].$1,
              icon:choices[i].$2.isNotEmpty && choices[i].$2.first.type=='only_me'
                ? Icons.lock_outline:Icons.people_outline,
              onTap:()=>Navigator.of(sheet).pop(i)),
        ]),
    );
    if(selected==null || !context.mounted)return null;
    var scope=choices[selected];
    if(scope.$2.isEmpty){
      final isCircle=scope.$1.contains('Circles');
      final available=isCircle?circleChoices:friendChoices;
      final multi=await _chooseMultiple(context,available);
      if(multi==null||multi.isEmpty)return null;
      scope=(isCircle?'Selected Circles ('+multi.length.toString()+')'
        :'Selected friends ('+multi.length.toString()+')',multi);
    }
    for(final entry in scope.$2.where((value)=>value.type=='circle')){

      try{
        if(!await repo.circleConsent(entry.id!)){
          if(!context.mounted)return null;
          final consent=await showOrbitCircleSheet<bool>(
            context:context,title:'Circle Check-In permission',
            builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
              const Text('Allow Check-In sharing with this Circle? '
                'You can revoke it any time. Your global privacy settings '
                'still control access.'),
              const SizedBox(height:16),
              AppPrimaryButton(label:'Allow Circle Check-In',
                onPressed:()=>Navigator.of(sheet).pop(true)),
            ]),
          );
          if(consent!=true)return null;
          await repo.setCircleConsent(entry.id!,true);
        }
      }catch(e){
        message(context,e is OrbitIdentityException?e.message:
          'Circle permission is unavailable.');
        return null;
      }
    }
    return scope;
  }

  static Future<List<OrbitCheckInScope>?> _chooseMultiple(
      BuildContext context,
      List<(String,List<OrbitCheckInScope>)> available) async {
    final selected=<int>{};
    return showOrbitCircleSheet<List<OrbitCheckInScope>>(
      context:context,title:'Select recipients',
      builder:(sheet)=>StatefulBuilder(builder:(sheet,update)=>Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          const Text('Select up to 25. Only eligible people or Circles '
            'can view your Check-In after the server verifies consent.'),
          const SizedBox(height:12),
          for(var i=0;i<available.length;i++)
            OrbitCircleSheetAction(
              title:(selected.contains(i)?'✓ ':'')+available[i].$1,
              icon:selected.contains(i)?Icons.check_circle_outline:
                Icons.person_outline,
              onTap:()=>update((){
                if(selected.contains(i)){selected.remove(i);}
                else if(selected.length<25){selected.add(i);}
              })),
          const SizedBox(height:12),
          AppPrimaryButton(label:'Use selected ('+selected.length.toString()+')',
            enabled:selected.isNotEmpty,
            onPressed:(){
              final indexes=selected.toList()..sort();
              Navigator.of(sheet).pop(indexes.map(
                (index)=>available[index].$2.first).toList());
            }),
        ],
      )),
    );
  }

  static Future<void> showMine(BuildContext context,
      {OrbitCheckInRepository? repository,String? cursor}) async {
    final repo=repository??OrbitCheckInRepository();
    OrbitCheckInPage? page;
    List<OrbitPendingCheckIn> pending=const [];
    try {
      pending=await repo.pending();
      page=await repo.page('mine',cursor:cursor);
    }catch(e){
      if(e is OrbitIdentityException && e.statusCode!=null){
        message(context,e.message);
        return;
      }
      try{pending=await repo.pending();}catch(_){}
    }
    if(!context.mounted)return;
    await showOrbitCircleSheet<void>(context:context,title:'My Check-Ins',
      builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
        if(pending.isNotEmpty)OrbitCircleSheetAction(
          title:'Retry pending Check-Ins ('+pending.length.toString()+')',
          icon:Icons.refresh_rounded,onTap:(){
            Navigator.of(sheet).pop();
            unawaited(() async{
              try{await repo.retryPending();}catch(_){}
              if(context.mounted)await showMine(context,repository:repo);
            }());
          }),
        for(final item in pending)OrbitCircleSheetAction(
          title:'Queued: '+(item.text??item.type),
          icon:Icons.schedule_rounded,onTap:()=>Navigator.of(sheet).pop()),
        if(page==null && pending.isEmpty)
          const Text('Reconnect to load your Check-Ins.'),
        if(page!=null && page.items.isEmpty && pending.isEmpty)
          const Text('No Check-Ins yet.'),
        if(page!=null)...page.items.map((record)=>OrbitCircleSheetAction(
          title:record.label+' · '+record.status,
          icon:record.status=='accepted'?Icons.favorite_outline:Icons.history,
          onTap:(){
            Navigator.of(sheet).pop();
            unawaited(_showMineActions(context,repo,record.id));
          },
        )),
        if(page?.nextCursor!=null)
          OrbitCircleSheetAction(title:'Load more',icon:Icons.expand_more,
            onTap:(){
              Navigator.of(sheet).pop();
              unawaited(showMine(context,repository:repo,
                cursor:page!.nextCursor));
            }),
      ]),
    );
  }

  static Future<void> _showMineActions(BuildContext context,
      OrbitCheckInRepository repo,String id) async {
    try {
      final fresh=await repo.detail(id);
      if(!context.mounted)return;
      final selection=await showOrbitCircleSheet<String>(
        context:context,title:'My Check-In',
        builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
          Text(fresh.label),
          const SizedBox(height:8),
          Text('Status: '+fresh.status),
          if(fresh.status=='accepted')
            OrbitCircleSheetAction(title:'Change audience',
              icon:Icons.people_outline,
              onTap:()=>Navigator.of(sheet).pop('audience')),
          if(fresh.status=='accepted')
            OrbitCircleSheetAction(title:'Set expiration',
              icon:Icons.event_outlined,
              onTap:()=>Navigator.of(sheet).pop('expiry')),
          OrbitCircleSheetAction(title:'Withdraw Check-In',
            icon:Icons.delete_outline,destructive:true,
            onTap:()=>Navigator.of(sheet).pop('withdraw')),
        ]),
      );
      if(!context.mounted)return;
      if(selection=='audience'){
        final choice=await chooseAudience(context,repo);
        if(choice!=null){
          await repo.changeAudience(id,fresh.revision,choice.$2);
          message(context,'Audience updated. Previous access revoked.');
        }
      }else if(selection=='expiry'){
        await _setExpiration(context,repo,fresh.id);
      }else if(selection=='withdraw'){
        final yes=await showOrbitCircleSheet<bool>(
          context:context,title:'Withdraw Check-In?',
          builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
            const Text('This removes the update from recipient views.'),
            const SizedBox(height:16),
            AppPrimaryButton(label:'Withdraw',
              onPressed:()=>Navigator.of(sheet).pop(true)),
          ]),
        );
        if(yes==true){
          await repo.withdraw(id);
          message(context,'Check-In withdrawn.');
        }
      }
    }catch(e){
      message(context,e is OrbitIdentityException?e.message:
        'Check-In is no longer available.');
    }
  }

  /// Inline date and time selectors in the approved full-width Orbit sheet.
  /// No fixed expiry is assumed. Backend rejects any policy-violating date.
  static Future<void> _setExpiration(BuildContext context,
      OrbitCheckInRepository repo,String id) async {
    final now=DateTime.now();
    final today=DateTime(now.year,now.month,now.day);
    DateTime day=today.add(const Duration(days:1));
    var hour=12;
    var minute=0;
    final selected=await showOrbitCircleSheet<DateTime>(
      context:context,title:'Set Check-In expiration',
      builder:(sheet)=>StatefulBuilder(builder:(sheet,refresh)=>Column(
        mainAxisSize:MainAxisSize.min,children:[
          const Text('Choose when this Check-In should stop being visible. '
            'No expiration is set unless you save one.'),
          CalendarDatePicker(
            initialDate:day,firstDate:today,
            lastDate:today.add(const Duration(days:29)),
            onDateChanged:(value)=>refresh(()=>day=value)),
          Row(children:[
            const Text('Time  '),
            Expanded(child:DropdownButton<int>(
              isExpanded:true,value:hour,
              items:List.generate(24,(n)=>DropdownMenuItem<int>(
                value:n,child:Text(n.toString().padLeft(2,'0')))),
              onChanged:(value){if(value!=null)refresh(()=>hour=value);},
            )),
            const Text(' : '),
            Expanded(child:DropdownButton<int>(
              isExpanded:true,value:minute,
              items:List.generate(60,(n)=>DropdownMenuItem<int>(
                value:n,child:Text(n.toString().padLeft(2,'0')))),
              onChanged:(value){if(value!=null)refresh(()=>minute=value);},
            )),
          ]),
          const SizedBox(height:18),
          AppPrimaryButton(label:'Save expiration',onPressed:(){
            final chosen=DateTime(day.year,day.month,day.day,hour,minute);
            if(!chosen.isAfter(DateTime.now()))return;
            Navigator.of(sheet).pop(chosen);
          }),
          TextButton(onPressed:()=>Navigator.of(sheet).pop(
            DateTime.fromMillisecondsSinceEpoch(0)),
            child:const Text('No expiration')),
        ]),
      ),
    );
    if(!context.mounted || selected==null)return;
    try{
      await repo.changeExpiry(id,selected.millisecondsSinceEpoch==0?null:selected);
      message(context,'Check-In expiration updated.');
    }catch(e){
      message(context,e is OrbitIdentityException?e.message:
        'Could not update expiration.');
    }
  }

  static Future<void> showFeed(BuildContext context,
      {OrbitCheckInRepository? repository,String? cursor}) async {
    final repo=repository??OrbitCheckInRepository();
    try{
      // Fresh server feed only. No local feed fallback after privacy changes.
      final page=await repo.page('feed',cursor:cursor);
      if(!context.mounted)return;
      await showOrbitCircleSheet<void>(context:context,
        title:'Friends’ Check-Ins',
        builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
          if(page.items.isEmpty)const Text('No Check-Ins available right now.'),
          for(final record in page.items)
            OrbitCircleSheetAction(
              title:record.creatorName+' · Check-In',
              icon:Icons.favorite_border_rounded,
              onTap:(){
                Navigator.of(sheet).pop();
                unawaited(_openFreshDetail(context,repo,record.id));
              }),
          if(page.nextCursor!=null)
            OrbitCircleSheetAction(title:'Load more',icon:Icons.expand_more,
              onTap:(){
                Navigator.of(sheet).pop();
                unawaited(showFeed(context,repository:repo,cursor:page.nextCursor));
              }),
        ]),
      );
    }catch(e){
      message(context,e is OrbitIdentityException?e.message:
        'Could not load Check-Ins. Reconnect to refresh.');
    }
  }

  static Future<void> _openFreshDetail(BuildContext context,
      OrbitCheckInRepository repo,String id) async {
    try {
      final current=await repo.detail(id);
      if(!context.mounted)return;
      await showOrbitCircleSheet<void>(context:context,title:'Check-In',
        builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(current.creatorName,style:const TextStyle(fontWeight:FontWeight.w600)),
          const SizedBox(height:12),
          Text(current.label),
          const SizedBox(height:12),
          const Text('Visible only while the creator’s current sharing '
            'permissions and your relationship allow it.'),
          const SizedBox(height:12),
          AppPrimaryButton(label:'Close',onPressed:()=>Navigator.of(sheet).pop()),
        ]),
      );
    }catch(e){
      message(context,'This Check-In is no longer available to you.');
    }
  }
}
