import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

  /// Safe, user-visible status; never contains tokens, account IDs or keys.
  final ValueNotifier<String> registrationStatus =
      ValueNotifier<String>('Not connected');

  StreamSubscription<String>? _tokenChanges;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _tapped;
  String? _registeredOwner;
  DateTime? _lastRegisteredAt;
  bool _starting=false;
  bool _active=false;

  Future<void> configure({bool force=false}) async {
    if(_starting)return;
    _starting=true;
    String phase='checking account settings';
    try {
      registrationStatus.value='Checking Orbit push registration…';
      final owner=await _identity.currentLocalSocialOwner();
      if(owner==null){
        await stop();
        registrationStatus.value='Sign in to register for push notifications.';
        return;
      }
      final bootstrap=await _repository.pushBootstrap();
      if(!bootstrap.enabled){
        await stop();
        registrationStatus.value='Push is disabled in Orbit account or server settings.';
        return;
      }
      if(_active&&_registeredOwner==owner&&!force){
        // A previously registered token may have been disabled server-side
        // (e.g. after a session/consent change). Reconfirm at most every six
        // hours; avoid repeated Firebase setup and duplicate listeners.
        if(_lastRegisteredAt!=null &&
           DateTime.now().difference(_lastRegisteredAt!)<
               const Duration(hours:6)){
          registrationStatus.value='Connected — push token registered.';
          return;
        }
        phase='refreshing device registration';
        final currentToken=await FirebaseMessaging.instance.getToken();
        if(currentToken!=null&&currentToken.isNotEmpty &&
           await _identity.currentLocalSocialOwner()==owner){
          await _repository.registerDevice(
              currentToken,Platform.isIOS?'ios':'android');
          _lastRegisteredAt=DateTime.now();
          registrationStatus.value='Connected — push token registered.';
          return;
        }
      }
      // A manual retry must not revoke the existing server token first.
      await stop(unregister:false);
      registrationStatus.value='Connecting to Firebase…';
      phase='initializing Firebase';

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
      phase='requesting phone permission';
      final messaging=FirebaseMessaging.instance;
      final permissions=await messaging.requestPermission(
        alert:true,badge:true,sound:true,provisional:false);
      if(permissions.authorizationStatus!=AuthorizationStatus.authorized &&
         permissions.authorizationStatus!=AuthorizationStatus.provisional){
        registrationStatus.value='Phone notification permission is not granted.';
        return;
      }
      if(Platform.isIOS){
        final apns=await messaging.getAPNSToken();
        if(apns==null||apns.isEmpty){
          registrationStatus.value='Apple push setup is not ready.';
          return;
        }
      }
      phase='obtaining Firebase token';
      registrationStatus.value='Retrieving Firebase device token…';
      final token=await messaging.getToken();
      if(token==null||token.isEmpty){
        registrationStatus.value='Firebase token unavailable. Check Google Play services.';
        return;
      }
      if(await _identity.currentLocalSocialOwner()!=owner){
        registrationStatus.value='Account changed. Sign in and retry.';
        return;
      }
      phase='registering device with Orbit';
      registrationStatus.value='Registering this device with Orbit…';
      await _repository.registerDevice(token,Platform.isIOS?'ios':'android');
      _registeredOwner=owner;
      _lastRegisteredAt=DateTime.now();
      _active=true;
      registrationStatus.value='Connected — push token registered.';
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
    }on OrbitIdentityException catch(error){
      // Show only a safe HTTP status, never a token or server response body.
      final code=error.statusCode;
      registrationStatus.value=switch(code){
        401 => 'Session expired. Sign in and retry push registration.',
        403 => 'Device is not trusted or push consent is unavailable.',
        422 => 'Orbit rejected device registration. Check device approval.',
        503 => 'Orbit push provider is temporarily unavailable.',
        _ => 'Could not contact Orbit for push registration. Retry.',
      };
    }catch(_){
      // Surface a privacy-safe failure instead of silently hiding it.
      // The authenticated HTTPS inbox remains functional.
      registrationStatus.value=
          'Push connection failed while $phase. Retry while online.';
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
      _lastRegisteredAt=DateTime.now();
    }catch(_){
      // No provider token or exception details are written to UI or logs.
      registrationStatus.value='Push token refresh failed. Retry registration.';
    }
  }

  Future<void> stop({bool unregister=true}) async {
    final owner=_registeredOwner;
    _active=false;
    _registeredOwner=null;
    _lastRegisteredAt=null;
    await _tokenChanges?.cancel();
    await _foreground?.cancel();
    await _tapped?.cancel();
    _tokenChanges=null;
    _foreground=null;
    _tapped=null;
    registrationStatus.value='Not connected';
    // Never unregister a different account's device token after logout.
    if(unregister && owner!=null
        && await _identity.currentLocalSocialOwner()==owner){
      try {await _repository.unregisterCurrentDevice();}catch(_){}
    }
  }
}
