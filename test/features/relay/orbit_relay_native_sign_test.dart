import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/relay/data/orbit_relay_protocol.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_vodozemac_ffi.dart';

void main(){
  final native=OrbitVodozemacNative.tryLoad();
  final required=Platform.environment['ORBIT_M13_NATIVE_REQUIRED']=='1';
  test('native proof uses existing M13 identity and rejects non-Relay signing',() async {
    final bridge=native!;
    final key=base64Encode(List<int>.generate(32,(i)=>i+1));
    final account=bridge.invoke({'op':'account_create','pickle_key_b64':key,'device_id':'relay-test-device'});
    const message='orbit-relay-peer-v1|test-transcript';
    Map<String,dynamic> sign(String m)=>bridge.invoke({'op':'relay_sign','pickle_key_b64':key,
      'account_pickle':account['account_pickle'],'message_b64':base64Encode(utf8.encode(m))});
    final signature=sign(message)['signature_b64'] as String;
    expect(await relayVerify(message,signature,account['identity_ed25519'] as String),isTrue);
    expect(await relayVerify(message+'-modified',signature,account['identity_ed25519'] as String),isFalse);
    expect(()=>sign('unrelated-signing-context'),throwsException);
  },skip:native==null&&!required);
}
