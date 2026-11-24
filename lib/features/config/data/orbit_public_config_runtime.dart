import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../app_update/domain/orbit_installed_version.dart';

/// M1 public configuration is a UI hint, never permission or entitlement.
/// No private data, persistence, or implicit mapping of arbitrary Admin keys
/// to consumer API authorization. Consumers must use an explicitly reviewed key.
class OrbitPublicConfigSnapshot {
  const OrbitPublicConfigSnapshot._(this.flags,this.config);
  final Map<String,bool> flags;
  final Map<String,Object?> config;

  static Map<String,dynamic> _map(Object? raw){
    // PHP's empty associative collections serialize as [] on an empty registry.
    if(raw is List && raw.isEmpty)return {};
    if(raw is! Map)throw const FormatException('Invalid configuration map.');
    return Map<String,dynamic>.from(raw);
  }

  factory OrbitPublicConfigSnapshot.fromResponse(Map<String,dynamic> response){
    final data=_map(response['data']);
    if(data['version']!='v1')throw const FormatException('Unsupported configuration schema.');
    final flags=_map(data['flags']),config=_map(data['config']);
    if(flags.values.any((value)=>value is! bool)){
      throw const FormatException('Invalid feature flag.');
    }
    return OrbitPublicConfigSnapshot._(
      Map<String,bool>.unmodifiable(flags.cast<String,bool>()),
      Map<String,Object?>.unmodifiable(config));
  }

  /// Missing / unknown keys are not an authorization to enable a feature.
  bool flag(String key)=>flags[key]==true;
}

/// A single optional refresh on launch/resume. It never blocks startup,
/// unlocks Home, overrides environment feature gates, or changes UI styling.
class OrbitPublicConfigRuntime extends ChangeNotifier with WidgetsBindingObserver {
  OrbitPublicConfigRuntime({OrbitIdentityClient? identity})
    :_identity=identity??OrbitIdentityClient.instance;
  static final instance=OrbitPublicConfigRuntime();
  final OrbitIdentityClient _identity;
  OrbitPublicConfigSnapshot? _snapshot;
  OrbitPublicConfigSnapshot? get snapshot=>_snapshot;
  bool _started=false;
  int _epoch=0;

  void start(){
    if(_started)return;
    _started=true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(refresh());
  }

  Future<void> refresh({String? platform}) async {
    final serial=++_epoch;
    final target=platform??(kIsWeb?'web':switch(defaultTargetPlatform){
      TargetPlatform.iOS=>'ios',TargetPlatform.android=>'android',_=>null,
    });
    if(target==null)return;
    try {
      final response=await _identity.publicConfigBootstrap(
        platform:target,appVersion:kOrbitInstalledAppVersion)
        .timeout(const Duration(seconds:8));
      final next=OrbitPublicConfigSnapshot.fromResponse(response);
      if(serial!=_epoch)return;
      _snapshot=next;
    }catch(_){
      if(serial!=_epoch)return;
      _snapshot=null;
    }
    notifyListeners();
  }

  @override
  void dispose(){
    ++_epoch;
    if(_started)WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
