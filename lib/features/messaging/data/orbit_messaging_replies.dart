import 'dart:convert';
import 'dart:typed_data';

/// Reply references stay inside recipient-specific authenticated ciphertext.
/// The server never receives a readable quoted message or target identifier.
class OrbitEncryptedReply {
  const OrbitEncryptedReply({required this.targetId,required this.text});
  final String targetId,text;
  Uint8List encode(){
    if(targetId.trim().isEmpty||targetId.length>128||
       text.trim().isEmpty||text.runes.length>4096){
      throw const FormatException('Invalid encrypted reply.');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'v':1,'type':'orbit_m13_reply',
      'target_id':targetId,'text':text.trim(),
    })));
  }
  static OrbitEncryptedReply? fromText(String raw){
    try{
      final obj=jsonDecode(raw);
      if(obj is! Map||obj['v']!=1||obj['type']!='orbit_m13_reply'||
         obj['target_id'] is! String||obj['text'] is! String)return null;
      final reply=OrbitEncryptedReply(targetId:obj['target_id'] as String,
        text:obj['text'] as String);
      if(reply.targetId.trim().isEmpty||reply.targetId.length>128||
         reply.text.trim().isEmpty||reply.text.runes.length>4096)return null;
      return reply;
    }catch(_){return null;}
  }
}
