import 'dart:convert';
import 'dart:typed_data';

/// Sticker IDs are part of an authenticated M13 E2EE payload; only the
/// non-sensitive 'sticker' media kind is visible to Laravel.
class OrbitChatSticker {
  const OrbitChatSticker(this.id);
  final String id;

  static const ids=<String>{
    'orbit-heart','orbit-cheer','orbit-star','orbit-hello',
    'orbit-hug','orbit-coffee','orbit-party','orbit-smile',
  };

  String encode(){
    if(!ids.contains(id))throw const FormatException('Unknown Orbit sticker.');
    return jsonEncode(<String,Object>{
      'v':1,'type':'orbit_m13_sticker','id':id,
    });
  }

  Uint8List encodeBytes()=>Uint8List.fromList(utf8.encode(encode()));

  static OrbitChatSticker? tryParse(String? value){
    if(value==null)return null;
    try{
      final json=jsonDecode(value);
      if(json is! Map || json['v']!=1 ||
          json['type']!='orbit_m13_sticker' ||
          json['id'] is! String || !ids.contains(json['id']))return null;
      return OrbitChatSticker(json['id'] as String);
    }catch(_){return null;}
  }
}
