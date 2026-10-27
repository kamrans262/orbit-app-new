/// M10 private models. Never save coordinates or grants to disk.
class OrbitLocationPrivacy {
  const OrbitLocationPrivacy({required this.ghost,required this.sharing,required this.activity,required this.visibility});
  final bool ghost,sharing;
  final String activity,visibility;
  bool get canShare=>!ghost&&sharing&&activity!='Off'&&visibility!='Nobody';
  factory OrbitLocationPrivacy.fromJson(Map<String,dynamic> j)=>OrbitLocationPrivacy(
    ghost:j['ghost']!=false,sharing:j['sharing']==true,
    activity:j['activity'] is String?j['activity'] as String:'Off',
    visibility:j['visibility'] is String?j['visibility'] as String:'Nobody');
}
class OrbitLocationCapabilities {
  const OrbitLocationCapabilities({required this.global,required this.latestTtl,required this.untilLeaving,required this.realtimeAvailable});
  final OrbitLocationPrivacy global;
  final int latestTtl;
  final bool untilLeaving,realtimeAvailable;
  factory OrbitLocationCapabilities.fromJson(Map<String,dynamic> j) {
    final g=j['global'];
    if(g is! Map)throw const FormatException('Invalid location privacy.');
    return OrbitLocationCapabilities(global:OrbitLocationPrivacy.fromJson(Map<String,dynamic>.from(g)),
      latestTtl:(j['latest_ttl_seconds'] as num?)?.toInt()??120,
      untilLeaving:j['until_leaving_available']==true,realtimeAvailable:j['realtime_available']==true);
  }
}
class OrbitLocationShare {
  const OrbitLocationShare({required this.id,required this.audienceType,required this.audienceId,required this.precision,required this.duration,required this.status,this.expiresAt,this.exitRadius});
  final String id,audienceType,audienceId,precision,duration,status;
  final DateTime? expiresAt;
  final int? exitRadius;
  bool get active=>status=='active'&&(expiresAt==null||expiresAt!.isAfter(DateTime.now().toUtc()));
  factory OrbitLocationShare.fromJson(Map<String,dynamic> j) {
    if(j['id'] is! String||j['audience_id'] is! String)throw const FormatException('Invalid grant.');
    return OrbitLocationShare(id:j['id'] as String,audienceType:j['audience_type'] as String,
      audienceId:j['audience_id'] as String,precision:j['precision'] as String,
      duration:j['duration'] as String,status:j['status'] as String,
      expiresAt:DateTime.tryParse(j['expires_at'] as String? ?? '')?.toUtc(),
      exitRadius:(j['exit_radius_m'] as num?)?.toInt());
  }
}
class OrbitLocationMarker {
  const OrbitLocationMarker({required this.userId,required this.latitude,required this.longitude,
    required this.precision,required this.observedAt,required this.ageSeconds,required this.state});
  final String userId,precision,state;
  final double latitude,longitude;
  final DateTime observedAt;
  final int ageSeconds;
  String get freshness=>(state=='paused'?'Paused · ':'Updated ')+ageSeconds.toString()+'s ago';
  factory OrbitLocationMarker.fromJson(Map<String,dynamic> j) {
    final id=j['user_id'],lat=j['latitude'],lng=j['longitude'],age=j['age_seconds'];
    final observed=DateTime.tryParse(j['observed_at'] as String? ?? '');
    if(id is! String||id.isEmpty||lat is! num||lng is! num||
      !lat.toDouble().isFinite||!lng.toDouble().isFinite||
      lat < -90||lat > 90||lng < -180||lng > 180||age is! num||age<0||
      observed==null||!['precise','approximate'].contains(j['precision'])||
      !['updated','paused'].contains(j['state']))throw const FormatException('Invalid private marker.');
    return OrbitLocationMarker(userId:id,latitude:lat.toDouble(),longitude:lng.toDouble(),
      precision:j['precision'] as String,observedAt:observed.toUtc(),
      ageSeconds:age.toInt(),state:j['state'] as String);
  }
}
class OrbitLocationMapSnapshot {
  const OrbitLocationMapSnapshot({required this.markers,required this.serverTime,required this.realtimeAvailable});
  final List<OrbitLocationMarker> markers;
  final DateTime serverTime;
  final bool realtimeAvailable;
  factory OrbitLocationMapSnapshot.fromJson(Map<String,dynamic> j) {
    final list=j['markers'],time=DateTime.tryParse(j['server_time'] as String? ?? '');
    if(list is! List||time==null||j['live_claimed']==true)throw const FormatException('Untrusted map.');
    final markers=<OrbitLocationMarker>[],seen=<String>{};
    for(final raw in list) {
      if(raw is! Map)throw const FormatException('Invalid marker list.');
      final m=OrbitLocationMarker.fromJson(Map<String,dynamic>.from(raw));
      if(m.ageSeconds>120||!seen.add(m.userId))continue;
      markers.add(m);
    }
    return OrbitLocationMapSnapshot(markers:List.unmodifiable(markers),
      serverTime:time.toUtc(),realtimeAvailable:j['realtime_available']==true);
  }
}
