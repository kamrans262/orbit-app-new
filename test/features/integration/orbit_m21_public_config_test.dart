import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/config/data/orbit_public_config_runtime.dart';

Map<String,dynamic> _response(bool enabled)=>{'data':{
  'version':'v1','flags':{'test.ui':enabled},'config':{'test.limit':15},
}};
class _Identity extends OrbitIdentityClient {
  bool enabled=true,unavailable=false;
  Completer<Map<String,dynamic>>? pending;
  String? platform,version;
  @override
  Future<Map<String,dynamic>> publicConfigBootstrap({
    required String platform,required String appVersion,
  }) async {
    this.platform=platform;version=appVersion;
    if(unavailable)throw OrbitIdentityException('Unavailable',503);
    if(pending!=null)return pending!.future;
    return _response(enabled);
  }
}

void main(){
  test('M1 current public flags and typed values; unknown flags remain off',() async {
    final id=_Identity();
    final runtime=OrbitPublicConfigRuntime(identity:id);
    addTearDown(runtime.dispose);
    await runtime.refresh(platform:'android');
    expect(id.platform,'android');
    expect(id.version,matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(runtime.snapshot?.flag('test.ui'),true);
    expect(runtime.snapshot?.flag('missing'),false);
    expect(runtime.snapshot?.config['test.limit'],15);
    id.enabled=false;
    await runtime.refresh(platform:'android');
    expect(runtime.snapshot?.flag('test.ui'),false);
    id.unavailable=true;
    await runtime.refresh(platform:'android');
    expect(runtime.snapshot,isNull);
  });

  test('M1 empty registry and malformed data fail closed',(){
    final empty=OrbitPublicConfigSnapshot.fromResponse({'data':{
      'version':'v1','flags':[],'config':[],
    }});
    expect(empty.flag('missing'),false);
    expect(()=>OrbitPublicConfigSnapshot.fromResponse({'data':{
      'version':'v1','flags':{'unsafe':'true'},'config':{},
    }}),throwsFormatException);
  });

  test('Late prior bootstrap cannot replace newer Admin configuration',() async {
    final id=_Identity();
    final runtime=OrbitPublicConfigRuntime(identity:id);
    addTearDown(runtime.dispose);
    final pending=Completer<Map<String,dynamic>>();
    id.pending=pending;
    final old=runtime.refresh(platform:'ios');
    id.pending=null;
    id.enabled=false;
    await runtime.refresh(platform:'ios');
    pending.complete(_response(true));
    await old;
    expect(runtime.snapshot?.flag('test.ui'),false);
  });
}
