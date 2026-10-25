import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_m7_rollout.dart';
import 'orbit_moment_repository.dart';
import 'orbit_moment_intent_vault.dart';

/// OS best-effort background recovery of ciphertext the user has ALREADY
/// explicitly queued. No camera capture, drafts awaiting review, or automatic
/// audience expansion is allowed. The backend remains the ACL authority.
/// Android WorkManager and iOS BGTaskScheduler are opportunistic: an OS force
/// stop, device policies, battery limits or iOS expiration can defer execution.
abstract final class OrbitM7BackgroundRetry {
  static const taskName='com.example.orbitUi.m7.encrypted_retry';
  static bool _initialized=false;

  static Future<void> initialize() async {
    if(!Platform.isAndroid && !Platform.isIOS)return;
    if(_initialized)return;
    await Workmanager().initialize(orbitM7BackgroundDispatcher);
    _initialized=true;
  }

  /// Registered only after encrypted bytes and user intent are durably saved.
  /// A periodic task permits recovery after an ordinary OS process kill.
  static Future<void> schedule() async {
    if(!OrbitM7Rollout.enabled)return;
    if(!Platform.isAndroid && !Platform.isIOS)return;
    await initialize();
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency:const Duration(minutes:15),
      constraints:Constraints(networkType:NetworkType.connected),
      existingWorkPolicy:ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Stop scheduled work when the user signs out or revokes this installation.
  /// An already running callback always rechecks authenticated identity.
  static Future<void> cancel() async {
    if(!Platform.isAndroid && !Platform.isIOS)return;
    try{
      await initialize();
      await Workmanager().cancelByUniqueName(taskName);
    }catch(_){
      // A scheduler being unavailable cannot block local logout.
    }
  }

  /// Stop waking the OS when no safely retryable encrypted intent remains.
  /// Keep any exhausted/expired ciphertext for explicit user review in Orbit.
  static Future<void> cancelWhenIdle() async {
    if(!Platform.isAndroid && !Platform.isIOS)return;
    try {
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null){await cancel();return;}
      final queued=await OrbitMomentIntentVault().pending(owner);
      final now=DateTime.now().toUtc();
      final eligible=queued.any((item)=>
        item.attemptCount<8 &&
        !now.difference(item.createdAt).isNegative &&
        now.difference(item.createdAt)<=const Duration(days:7));
      if(!eligible)await cancel();
    }catch(_){
      // A storage read failure must not discard unconfirmed private drafts.
    }
  }

  /// This can run in an OS-launched headless Flutter engine.
  static Future<bool> execute({
    Future<OrbitRestoreState> Function()? verifySession,
    Future<int> Function()? resume,
  }) async {
    if(!OrbitM7Rollout.enabled)return true;
    try {
      final status=await (verifySession??OrbitIdentityClient.instance.restoreSession)();
      if(status!=OrbitRestoreState.authenticated)return true;
      // The retry repository only resumes existing encrypted publication intents
      // for this verified account, checks the current allowed audience and
      // requires an idempotent Laravel publication receipt before completion.
      await (resume??OrbitMomentRepository().resumePendingPublishes)();
      await cancelWhenIdle();
      return true;
    }catch(_){
      // Keep the OS periodic work scheduled and preserve the ciphertext for
      // a later retry. Never issue an unverified success notification.
      return false;
    }
  }
}

@pragma('vm:entry-point')
void orbitM7BackgroundDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task,inputData) async {
    if(task!=OrbitM7BackgroundRetry.taskName)return true;
    return OrbitM7BackgroundRetry.execute();
  });
}
