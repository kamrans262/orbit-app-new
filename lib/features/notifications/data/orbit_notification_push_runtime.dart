import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_notification_repository.dart';

/// Shared M14 generic FCM invalidation listener. No Firebase initialization,
/// token registration or permission prompt when Laravel push-bootstrap is OFF.
/// Push payloads have no user/target identifiers or private content.
class OrbitNotificationPushRuntime {
  OrbitNotificationPushRuntime._();
  static final OrbitNotificationPushRuntime instance=
      OrbitNotificationPushRuntime._();

  final OrbitIdentityClient _identity=OrbitIdentityClient.instance;
  final OrbitNotificationRepository _repository=OrbitNotificationRepository();
  final StreamController<void> _updates=StreamController<void>.broadcast();
  final StreamController<void> _opened=StreamController<void>.broadcast();

  Stream<void> get updates=>_updates.stream;
  Stream<void> get opened=>_opened.stream;

  StreamSubscription<String>? _tokenChanges;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _tapped;
  String? _registeredOwner;
  bool _starting=false;
  bool _active=false;

  Future<void> configure() async {
    if(_starting)return;
    _starting=true;
    try {
      final owner=await _identity.currentLocalSocialOwner();
      if(owner==null){await stop();return;}
      final bootstrap=await _repository.pushBootstrap();
      if(!bootstrap.enabled){await stop();return;}
      if(_active&&_registeredOwner==owner)return;
      await stop();

      final options=bootstrap.options;
      String field(String key){
        final value=options[key];
        if(value is! String || value.trim().isEmpty){
          throw const FormatException('Verified Firebase settings unavailable.');
        }
        return value;
      }
      final project=field('project_id');
      final appId=Platform.isIOS?field('ios_app_id'):field('android_app_id');
      final firebaseOptions=FirebaseOptions(
        apiKey:field('api_key'),
        appId:appId,
        messagingSenderId:field('sender_id'),
        projectId:project,
        iosBundleId:Platform.isIOS?field('ios_bundle_id'):null,
      );
      if(Firebase.apps.isEmpty){
        await Firebase.initializeApp(options:firebaseOptions);
      }else{
        final existing=Firebase.app().options;
        if(existing.projectId!=project || existing.appId!=appId){
          // A token issued for a different Firebase app may never be
          // registered with the current Orbit backend.
          throw StateError('Firebase app registration mismatch.');
        }
      }
      final messaging=FirebaseMessaging.instance;
      final permissions=await messaging.requestPermission(
        alert:true,badge:true,sound:true,provisional:false);
      if(permissions.authorizationStatus!=AuthorizationStatus.authorized &&
         permissions.authorizationStatus!=AuthorizationStatus.provisional){
        return;
      }
      if(Platform.isIOS){
        final apns=await messaging.getAPNSToken();
        if(apns==null||apns.isEmpty)return;
      }
      final token=await messaging.getToken();
      if(token==null||token.isEmpty)return;
      if(await _identity.currentLocalSocialOwner()!=owner)return;
      await _repository.registerDevice(token,Platform.isIOS?'ios':'android');
      _registeredOwner=owner;
      _active=true;
      _tokenChanges=messaging.onTokenRefresh.listen((next){
        if(next.isEmpty)return;
        unawaited(_rotateToken(next,owner));
      },onError:(_){});
      _foreground=FirebaseMessaging.onMessage.listen((message){
        if(message.data['type']=='notification_available')_updates.add(null);
      },onError:(_){});
      _tapped=FirebaseMessaging.onMessageOpenedApp.listen((message){
        if(message.data['type']=='notification_available')_opened.add(null);
      },onError:(_){});
      // Only a provider-confirmed generic event may request opening the
      // authenticated inbox. Never navigate to a payload-specified target.
      final initial=await messaging.getInitialMessage();
      if(initial?.data['type']=='notification_available' &&
         await _identity.currentLocalSocialOwner()==owner){
        _opened.add(null);
      }
    }catch(_){
      // Firebase is optional. The HTTPS inbox remains functional when the
      // provider, platform configuration, or connection is unavailable.
    }finally{
      _starting=false;
    }
  }

  Future<void> _rotateToken(String next,String owner) async {
    if(!_active||_registeredOwner!=owner ||
       await _identity.currentLocalSocialOwner()!=owner)return;
    try{
      // Registration still requires server opt-in and current device trust.
      final settings=await _repository.pushBootstrap();
      if(!settings.enabled)return;
      await _repository.registerDevice(next,Platform.isIOS?'ios':'android');
    }catch(_){
      // Token rotation will be retried through a later verified bootstrap.
    }
  }

  Future<void> stop({bool unregister=true}) async {
    final owner=_registeredOwner;
    _active=false;
    _registeredOwner=null;
    await _tokenChanges?.cancel();
    await _foreground?.cancel();
    await _tapped?.cancel();
    _tokenChanges=null;
    _foreground=null;
    _tapped=null;
    // Never unregister a different account's device token after logout.
    if(unregister && owner!=null
        && await _identity.currentLocalSocialOwner()==owner){
      try {await _repository.unregisterCurrentDevice();}catch(_){}
    }
  }
}
