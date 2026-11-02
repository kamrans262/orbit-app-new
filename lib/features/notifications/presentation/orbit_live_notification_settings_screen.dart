import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
    extends State<OrbitLiveNotificationSettingsScreen>
    with WidgetsBindingObserver {
  late final OrbitProfileSettingsRepository _repo=
      widget.repository??OrbitProfileSettingsRepository();
  NotificationSettings? _current;
  String? _error;
  bool _loading=true;
  PermissionStatus? _osStatus;
  int _epoch=0;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _readSystemPermission();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed)_readSystemPermission();
  }
  Future<void> _readSystemPermission() async {
    try{
      final status=await Permission.notification.status;
      if(mounted)setState(()=>_osStatus=status);
    }catch(_){
      if(mounted)setState(()=>_osStatus=null);
    }
  }
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
      return NotificationScreen(
        initialSettings:current,onSaveSettings:_save,
        systemPermissionFooter:Semantics(
          label:'System notification permission status',
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const SizedBox(height:6),
              Text(_osStatus==null
                ?'Device permission: Not checked'
                :_osStatus!.isGranted
                  ?'Device notifications: Allowed'
                  :'Device notifications: Blocked or not granted',
                  style:AppTypography.bodyMuted),
              TextButton(
                onPressed:() async {
                  await openAppSettings();
                  if(mounted)await _readSystemPermission();
                },
                child:const Text('Open phone notification settings')),
              const Text('Changing this setting does not enable Firebase push '
                'unless the Orbit server has activated delivery.',
                style:TextStyle(fontSize:12,color:Color(0xFF5D6574))),
          ])),
      );
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
  void dispose(){
    ++_epoch;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
