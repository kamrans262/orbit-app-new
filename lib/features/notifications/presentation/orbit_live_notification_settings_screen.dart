import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../profile/data/orbit_profile_settings_repository.dart';
import '../../profile/domain/models/notification_settings.dart';
import '../../profile/presentation/screens/notification_screen.dart';
import '../data/orbit_notification_push_runtime.dart';

/// Uses the approved M3 NotificationScreen without demo preferences.
class OrbitLiveNotificationSettingsScreen extends StatefulWidget {
  const OrbitLiveNotificationSettingsScreen({super.key,this.repository});
  final OrbitProfileSettingsRepository? repository;
  @override
  State<OrbitLiveNotificationSettingsScreen> createState() =>
      _OrbitLiveNotificationSettingsScreenState();
}
class _OrbitLiveNotificationSettingsScreenState
    extends State<OrbitLiveNotificationSettingsScreen> {
  late final OrbitProfileSettingsRepository _repo=
      widget.repository??OrbitProfileSettingsRepository();
  NotificationSettings? _current;
  String? _error;
  bool _loading=true;
  int _epoch=0;

  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    final epoch=++_epoch;
    setState((){_loading=true;_error=null;});
    try{
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null)throw StateError('Signed out');
      final value=await _repo.loadNotifications();
      if(!mounted||epoch!=_epoch)return;
      if(await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner) {
        throw StateError('Account changed');
      }
      if(mounted&&epoch==_epoch)setState((){
        _current=value;_loading=false;
      });
    }catch(_){
      if(mounted&&epoch==_epoch)setState((){
        _loading=false;_current=null;
        _error='Notification preferences are unavailable. Please retry.';
      });
    }
  }

  Future<NotificationSettings> _save(NotificationSettings requested) async {
    final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
    if(owner==null)throw StateError('Session unavailable');
    final confirmed=await _repo.saveNotifications(requested);
    if(await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner) {
      throw StateError('Account changed');
    }
    // A successful preference save does not prove FCM is provisioned.
    if(!confirmed.pushNotificationsEnabled) {
      await OrbitNotificationPushRuntime.instance.stop();
    }else{
      await OrbitNotificationPushRuntime.instance.configure();
    }
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final current=_current;
    if(!_loading && current!=null) {
      return NotificationScreen(initialSettings:current,onSaveSettings:_save);
    }
    return Scaffold(
      backgroundColor:AppColors.background,
      body:SafeArea(child:Column(children:[
        const Padding(padding:EdgeInsets.fromLTRB(20,20,20,0),
          child:AppScreenHeader(title:'Notification')),
        Expanded(child:Center(child:_loading
          ?const CircularProgressIndicator(color:AppColors.primaryEnd)
          :Column(mainAxisSize:MainAxisSize.min,children:[
              Text(_error??'Notification settings unavailable.',
                style:AppTypography.bodyMuted,textAlign:TextAlign.center),
              const SizedBox(height:12),
              TextButton(onPressed:_load,child:const Text('Try again')),
            ]))),
      ])),
    );
  }
  @override
  void dispose(){++_epoch;super.dispose();}
}
