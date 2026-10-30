import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_local_vault.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_reactions.dart';

OrbitLocalDecryptedMessage _local(String id,String user,String kind,String text,int sec)=>
  OrbitLocalDecryptedMessage(id:id,conversationId:'room',
    senderId:user,kind:kind,text:text,
    createdAt:DateTime.utc(2026,10,30).add(Duration(seconds:sec)));

void main(){
  test('Encrypted reactions remain private, strictly validated and reversible',(){
    const emoji='❤️';
    final encoded=OrbitEncryptedReaction(targetId:'msg-1',selected:emoji).encode();
    final parsed=OrbitEncryptedReaction.fromText(utf8.decode(encoded));
    expect(parsed?.targetId,'msg-1');
    expect(parsed?.selected,emoji);
    expect(utf8.decode(encoded),isNot(contains('https://')));
    expect(OrbitEncryptedReaction.fromText('{"v":1,"type":"orbit_m13_reaction","target_id":"x","selected":"fake"}'),isNull);
    expect(OrbitEncryptedReaction.fromText('not JSON'),isNull);
    expect(()=>const OrbitEncryptedReaction(
      targetId:'msg',selected:'unverified').encode(),throwsFormatException);
  });

  test('Repeated reactions replace per-author choices without inflating counts',(){
    String command(String target,String? emoji)=>utf8.decode(
      OrbitEncryptedReaction(targetId:target,selected:emoji).encode());
    final events=[
      _local('msg-1','alice','text','Hello',0),
      _local('msg-2','bob','text','Hi',1),
      _local('r-1','alice','reaction',command('msg-1','❤️'),2),
      _local('r-2','bob','reaction',command('msg-1','❤️'),3),
      _local('r-3','alice','reaction',command('msg-1','👍'),4),
      _local('r-4','bob','reaction',command('msg-1',null),5),
      _local('r-5','mallory','reaction',command('absent','❤️'),6),
    ];
    final result=OrbitReactionReducer.fold(events,localUser:'alice');
    expect(result['msg-1']?.counts,{'👍':1});
    expect(result['msg-1']?.selected,'👍');
    expect(result.containsKey('absent'),false);
    expect(result.containsKey('msg-2'),false);
    final bob=OrbitReactionReducer.fold(events,localUser:'bob');
    expect(bob['msg-1']?.selected,isNull);
  });
}
