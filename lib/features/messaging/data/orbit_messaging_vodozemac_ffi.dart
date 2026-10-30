import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'orbit_messaging_models.dart';

typedef _NativeCall = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartCall = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _NativeFree = Void Function(Pointer<Utf8>);
typedef _DartFree = void Function(Pointer<Utf8>);

/// First-party FFI only; NO AGPL Dart/Flutter wrapper dependency.
/// The linked Rust crate uses Apache-2.0 vodozemac for audited Olm/Megolm.
/// Fail closed when an expected, signed native binary is not installed.
///
/// No request, response, session pickle, symmetric key or message plaintext
/// may be logged by this bridge or forwarded through analytics.
class OrbitVodozemacNative {
  OrbitVodozemacNative._(this._call,this._free);
  final _DartCall _call;
  final _DartFree _free;

  static OrbitVodozemacNative? tryLoad() {
    try {
      final DynamicLibrary lib;
      if(Platform.isIOS) {
        // iOS builds must statically link liborbit_vodozemac.a.
        lib=DynamicLibrary.process();
      }else if(Platform.isAndroid){
        lib=DynamicLibrary.open('liborbit_vodozemac.so');
      }else if(Platform.isLinux){
        // Linux CI validates real Dart<->Rust ABI with the same audited
        // native bridge. Mobile builds still load their platform binaries.
        lib=DynamicLibrary.open('liborbit_vodozemac.so');
      }else if(Platform.isMacOS){
        lib=DynamicLibrary.open('liborbit_vodozemac.dylib');
      }else if(Platform.isWindows){
        lib=DynamicLibrary.open('orbit_vodozemac.dll');
      }else{
        return null;
      }
      final call=lib.lookupFunction<_NativeCall,_DartCall>(
        'orbit_vodozemac_call');
      final free=lib.lookupFunction<_NativeFree,_DartFree>(
        'orbit_vodozemac_free');
      final native=OrbitVodozemacNative._(call,free);
      final probe=native.invoke({'op':'bridge_version'});
      if(probe['abi']!=1 || probe['crypto']!='vodozemac')return null;
      return native;
    }catch(_){
      // This is a verified-release requirement, not a switch to plaintext.
      return null;
    }
  }

  Map<String,dynamic> invoke(Map<String,Object?> request) {
    final jsonString=jsonEncode(request);
    if(utf8.encode(jsonString).length>1000000){
      throw OrbitMessagingSecurityException(
        'Native crypto input exceeds the maximum size.',422);
    }
    final input=jsonString.toNativeUtf8();
    Pointer<Utf8> result=nullptr;
    try{
      result=_call(input);
      if(result==nullptr){
        throw OrbitMessagingSecurityException(
          'Native ratchet operation failed.',503);
      }
      final decoded=jsonDecode(result.toDartString());
      if(decoded is! Map || decoded['ok']!=true ||
          decoded['value'] is! Map){
        throw OrbitMessagingSecurityException(
          'Native ratchet refused an unauthenticated operation.',409);
      }
      return Map<String,dynamic>.from(decoded['value'] as Map);
    }finally{
      calloc.free(input);
      if(result!=nullptr)_free(result);
    }
  }
}
