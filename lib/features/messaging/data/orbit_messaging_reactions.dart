import 'dart:convert';
import 'dart:typed_data';

import 'orbit_messaging_local_vault.dart';

/// End-to-end encrypted reaction command. The Laravel server sees only
/// ciphertext kind="reaction"; targets/choices remain device-local.
class OrbitEncryptedReaction {
  const OrbitEncryptedReaction({required this.targetId,required this.selected});
  final String targetId;
  final String? selected;
  static const allowed=<String>{
    '❤️','👍','😂','😮','😢','👎',
  };

  Uint8List encode(){
    if(targetId.isEmpty||targetId.length>128||
        (selected!=null&&!allowed.contains(selected))){
      throw const FormatException('Unsupported encrypted reaction.');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'v':1,'type':'orbit_m13_reaction',
      'target_id':targetId,'selected':selected,
    })));
  }
  static OrbitEncryptedReaction? fromText(String input){
    try{
      final j=jsonDecode(input);
      if(j is! Map||j['v']!=1||
          j['type']!='orbit_m13_reaction'||j['target_id'] is! String||
          (j['selected']!=null && j['selected'] is! String)){
        return null;
      }
      final item=OrbitEncryptedReaction(
        targetId:j['target_id'] as String,
        selected:j['selected'] as String?);
      if(item.targetId.isEmpty||item.targetId.length>128||
          (item.selected!=null&&!allowed.contains(item.selected)))return null;
      return item;
    }catch(_){return null;}
  }
}

class OrbitReactionSummary {
  const OrbitReactionSummary({
    required this.counts,required this.selected,
  });
  final Map<String,int> counts;
  final String? selected;
}

/// Replay signed, decrypted reaction events in sequence, per sender.
/// A later event from the same sender replaces, never adds to, their previous
/// choice. Older revisions cannot inflate counts or overwrite other users.
class OrbitReactionReducer {
  static Map<String,OrbitReactionSummary> fold(
      List<OrbitLocalDecryptedMessage> history,{required String localUser}) {
    final targets=<String,Map<String,String?>>{};
    final originals=<String>{};
    for(final e in history){
      if(e.kind!='reaction')originals.add(e.id);
    }
    for(final e in history){
      if(e.kind!='reaction')continue;
      final reaction=OrbitEncryptedReaction.fromText(e.text);
      if(reaction==null||!originals.contains(reaction.targetId))continue;
      (targets[reaction.targetId]??=<String,String?>{})[e.senderId]=
        reaction.selected;
    }
    return {
      for(final entry in targets.entries)
        entry.key:OrbitReactionSummary(
          counts:_counts(entry.value),
          selected:entry.value[localUser],
        ),
    };
  }
  static Map<String,int> _counts(Map<String,String?> values){
    final counts=<String,int>{};
    for(final reaction in values.values){
      if(reaction!=null){
        counts[reaction]=(counts[reaction]??0)+1;
      }
    }
    return counts;
  }
}
