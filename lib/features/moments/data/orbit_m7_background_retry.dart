import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../auth/data/orbit_identity_client.dart';
import 'orbit_m7_rollout.dart';
import 'orbit_moment_repository.dart';

/// OS best-effort background recovery of ciphertext the user has ALREADY
/// explicitly queued. No camera capture, drafts awaiting review, or automatic
/// audience expansion is allowed. The backend remains the ACL authority.
/// Android WorkManager and iOS BGTaskScheduler are opportunistic: an OS force
/// stop, device policies, battery limits or iOS expiration can defer execution.
abstract final class OrbitM7BackgroundRetry {
  static const taskName='com.example.orbit_ui.m7.encrypted_retry';
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
