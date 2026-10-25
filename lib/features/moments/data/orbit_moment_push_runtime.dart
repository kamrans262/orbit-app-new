import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../auth/data/orbit_identity_client.dart';

/// M7 future FCM integration. NO Firebase initialization, token registration,
/// listeners or network traffic when Laravel returns enabled=false.
class OrbitMomentPushRuntime {
  OrbitMomentPushRuntime._();
  static final OrbitMomentPushRuntime instance=OrbitMomentPushRuntime._();

  final OrbitIdentityClient _identity=OrbitIdentityClient.instance;
  final StreamController<void> _updates=StreamController<void>.broadcast();
  Stream<void> get updates=>_updates.stream;

  StreamSubscription<String>? _tokenChanges;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  bool _starting=false;
  bool _active=false;
  String? _configuredOwner;

  Future<void> configure() async {
    if(_starting)return;
    _starting=true;
    try {
      final owner=await _identity.currentLocalSocialOwner();
      if(owner==null){await stop();return;}
      final raw=await _identity.socialRequest('GET',
        '/me/moments/push-bootstrap');
      final data=raw['data'];
      if(data is! Map || data['enabled']!=true){
        await stop();
        return;
      }
      if(_active && _configuredOwner==owner)return;
      await stop();
      final options=data['options'];
      if(options is! Map)throw const FormatException('FCM options unavailable.');
      String value(String key) {
        final v=options[key];
        if(v is! String || v.trim().isEmpty){
          throw const FormatException('Firebase client config is incomplete.');
        }
        return v;
      }
      final project=value('project_id');
      final appOptions=FirebaseOptions(
        apiKey:value('api_key'),
        appId:Platform.isIOS?value('ios_app_id'):value('android_app_id'),
        messagingSenderId:value('sender_id'),
        projectId:project,
        iosBundleId:Platform.isIOS?value('ios_bundle_id'):null,
      );
      FirebaseApp app;
      if(Firebase.apps.isEmpty){
        app=await Firebase.initializeApp(options:appOptions);
      }else{
        app=Firebase.app();
        if(app.options.projectId!=project){
          // Never register a token issued for a different Firebase project.
          throw StateError('Firebase project mismatch.');
        }
      }
      final messaging=FirebaseMessaging.instance;
      final permission=await messaging.requestPermission(
        alert:true,badge:true,sound:true,provisional:false);
      if(permission.authorizationStatus!=AuthorizationStatus.authorized &&
         permission.authorizationStatus!=AuthorizationStatus.provisional){
        return;
      }
      if(Platform.isIOS) {
        // An APNS token is needed before the FCM registration attempt.
        final apns=await messaging.getAPNSToken();
        if(apns==null || apns.isEmpty)return;
      }
      final token=await messaging.getToken();
      if(token==null || token.isEmpty)return;
      await _register(token,owner);
      _configuredOwner=owner;
      _active=true;
      _tokenChanges=messaging.onTokenRefresh.listen((next){
        if(next.isNotEmpty)unawaited(_register(next,owner));
      },onError:(_){});
      _foreground=FirebaseMessaging.onMessage.listen((msg){
        if(msg.data['type']=='moment_available')_updates.add(null);
      });
      _opened=FirebaseMessaging.onMessageOpenedApp.listen((msg){
        if(msg.data['type']=='moment_available')_updates.add(null);
      });
    }catch(_){
      // When Firebase has not yet been provided or a native platform is
      // unconfigured, keep HTTPS in-app notices working instead of crashing.
    }finally{_starting=false;}
  }

  Future<void> _register(String token,String owner) async {
    if(await _identity.currentLocalSocialOwner()!=owner)return;
    await _identity.socialRequest('POST','/me/moments/push-token',body:{
      'token':token,'platform':Platform.isIOS?'ios':'android',
    });
  }

  Future<void> stop() async {
    final owner=_configuredOwner;
    _active=false;_configuredOwner=null;
    await _tokenChanges?.cancel();_tokenChanges=null;
    await _foreground?.cancel();_foreground=null;
    await _opened?.cancel();_opened=null;
    // Never disclose tokens in application logs or caches.
    if(owner!=null && await _identity.currentLocalSocialOwner()==owner){
      try{
        await _identity.socialRequest('DELETE','/me/moments/push-token');
      }catch(_){}
    }
  }
}
