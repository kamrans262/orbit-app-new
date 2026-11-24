import 'package:flutter/foundation.dart';

abstract final class OrbitRealtimeRollout {
  static const selected=bool.fromEnvironment('ORBIT_M25_REALTIME_ENABLED',defaultValue:false);
  static const project=String.fromEnvironment('ORBIT_M25_FIREBASE_PROJECT_ID',defaultValue:'orbit-app-4cb36');
}

const orbitRealtimeModules=<String>{'presence','location','circles','social','moments','ping','check_in','messaging','notifications','plans','sos','activity'};

class OrbitRealtimeTicket {
  const OrbitRealtimeTicket({required this.uid,required this.generation,required this.token,
    required this.path,required this.project,required this.url,required this.apiKey,
    required this.appId,required this.sender,required this.modules,required this.lease,
    required this.renew,required this.poll,this.bundle});
  final String uid,generation,token,path,project,url,apiKey,appId,sender;
  final String? bundle;
  final Set<String> modules;
  final Duration lease,renew,poll;
  static final _uuid=RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  static OrbitRealtimeTicket? parse(Map<String,dynamic> response,{required TargetPlatform platform,
    required String expectedProject,required DateTime now,required Duration requestElapsed}){
    final raw=response['data'];
    if(raw is! Map||raw['schema_version']!=1)throw const FormatException('Invalid realtime contract.');
    if(raw['enabled']==false&&raw['transport']=='https')return null;
    if(raw['enabled']!=true||raw['transport']!='firebase_rtdb')throw const FormatException('Invalid transport.');
    String field(Map source,String name){
      final value=source[name];
      if(value is! String||value.isEmpty||value.length>8192)throw const FormatException('Invalid realtime field.');
      return value;
    }
    final uid=field(raw,'uid'),generation=field(raw,'generation'),path=field(raw,'signal_path');
    if(!_uuid.hasMatch(uid)||!_uuid.hasMatch(generation)||path!='orbit_m25/sessions/$uid/signal'){
      throw const FormatException('Invalid session scope.');
    }
    final f=raw['firebase'];
    if(f is! Map)throw const FormatException('Firebase options unavailable.');
    final project=field(f,'project_id'),url=field(f,'database_url'),sender=field(f,'sender_id'),appId=field(f,'app_id');
    final kind=platform==TargetPlatform.android?'android':platform==TargetPlatform.iOS?'ios':null;
    if(kind==null||project!=expectedProject||!RegExp(r'^[a-z][a-z0-9-]{4,62}$').hasMatch(project)
        ||!RegExp(r'^[0-9]+$').hasMatch(sender)
        ||!RegExp('^1:$sender:$kind:[a-f0-9]+\$').hasMatch(appId)){
      throw const FormatException('Firebase identity mismatch.');
    }
    final origin=Uri.tryParse(url);
    final host=RegExp('^${RegExp.escape(project)}' r'(?:-default-rtdb)?(?:\.firebaseio\.com|\.[a-z0-9-]+\.firebasedatabase\.app);
    if(origin==null||origin.scheme!='https'||!host.hasMatch(origin.host)||origin.hasPort||
      origin.userInfo.isNotEmpty||origin.hasQuery||origin.hasFragment||origin.path.isNotEmpty){
      throw const FormatException('Firebase origin mismatch.');
    }
    final token=field(raw,'custom_token');
    final expiry=raw['lease_until_ms'],renew=raw['renew_after_seconds'],poll=raw['fallback_min_poll_seconds'];
    final modules=raw['modules'];
    if(expiry is! int||renew is! int||renew<10||renew>30||poll is! int||poll<25||poll>60||
        modules is! List||modules.any((m)=>m is! String||!orbitRealtimeModules.contains(m))){
      throw const FormatException('Invalid realtime policy.');
    }
    // Clamp to the server's maximum lease, measured from request start, and
    // fail closed if the absolute deadline is already past. Never extend by skew.
    final remaining=expiry-now.millisecondsSinceEpoch;
    final maxRemaining=60000-requestElapsed.inMilliseconds;
    final ms=remaining<maxRemaining?remaining:maxRemaining;
    if(ms<=0)throw const FormatException('Expired lease.');
    return OrbitRealtimeTicket(uid:uid,generation:generation,token:token,path:path,project:project,url:url,
      apiKey:field(f,'api_key'),appId:appId,sender:sender,modules:Set.unmodifiable(modules.cast<String>()),
      lease:Duration(milliseconds:ms),renew:Duration(seconds:renew),poll:Duration(seconds:poll),
      bundle:kind=='ios'?field(f,'ios_bundle_id'):null);
  }

  static int revision(Object? raw){
    if(raw is! Map||raw.length!=2||raw['schema_version']!=1||raw['revision'] is! int||
       (raw['revision'] as int)<1){throw const FormatException('Invalid realtime signal.');}
    return raw['revision'] as int;
  }
}
);
    if(origin==null||origin.scheme!='https'||!host.hasMatch(origin.host)||origin.hasPort||
      origin.userInfo.isNotEmpty||origin.hasQuery||origin.hasFragment||origin.path.isNotEmpty){
      throw const FormatException('Firebase origin mismatch.');
    }
    final token=field(raw,'custom_token');
    final expiry=raw['lease_until_ms'],renew=raw['renew_after_seconds'],poll=raw['fallback_min_poll_seconds'];
    final modules=raw['modules'];
    if(expiry is! int||renew is! int||renew<10||renew>30||poll is! int||poll<25||poll>60||
        modules is! List||modules.any((m)=>m is! String||!orbitRealtimeModules.contains(m))){
      throw const FormatException('Invalid realtime policy.');
    }
    // Clamp to the server's maximum lease, measured from request start, and
    // fail closed if the absolute deadline is already past. Never extend by skew.
    final remaining=expiry-now.millisecondsSinceEpoch;
    final maxRemaining=60000-requestElapsed.inMilliseconds;
    final ms=remaining<maxRemaining?remaining:maxRemaining;
    if(ms<=0)throw const FormatException('Expired lease.');
    return OrbitRealtimeTicket(uid:uid,generation:generation,token:token,path:path,project:project,url:url,
      apiKey:field(f,'api_key'),appId:appId,sender:sender,modules:Set.unmodifiable(modules.cast<String>()),
      lease:Duration(milliseconds:ms),renew:Duration(seconds:renew),poll:Duration(seconds:poll),
      bundle:kind=='ios'?field(f,'ios_bundle_id'):null);
  }

  static int revision(Object? raw){
    if(raw is! Map||raw.length!=2||raw['schema_version']!=1||raw['revision'] is! int||
       (raw['revision'] as int)<1)throw const FormatException('Invalid realtime signal.');
    return raw['revision'] as int;
  }
}
