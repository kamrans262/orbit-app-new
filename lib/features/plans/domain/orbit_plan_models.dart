import 'package:flutter/foundation.dart';

@immutable
class OrbitPlanPerson {
  const OrbitPlanPerson({required this.id,required this.name,required this.state});
  final String id,name,state;
  factory OrbitPlanPerson.fromJson(Map<String,dynamic> j) {
    if(j['id'] is! String)throw const FormatException('Invalid Plan participant.');
    return OrbitPlanPerson(id:j['id'] as String,
      name:j['display_name'] as String? ?? 'Orbit member',
      state:j['state'] as String? ?? '');
  }
}

@immutable
class OrbitPlan {
  const OrbitPlan({required this.id,required this.title,required this.startsAt,
    required this.status,required this.revision,required this.organizerId,
    required this.organizerName,required this.myRsvp,required this.canEdit,
    this.description='',this.endsAt,this.placeLabel,this.placeRef,
    this.latitude,this.longitude,this.participants=const []});
  final String id,title,description,status,organizerId,organizerName;
  final String? myRsvp,placeLabel,placeRef;
  final DateTime startsAt;
  final DateTime? endsAt;
  final double? latitude,longitude;
  final int revision;
  final bool canEdit;
  final List<OrbitPlanPerson> participants;

  bool get isUpcoming=>status=='scheduled' && startsAt.isAfter(DateTime.now());
  bool get canRespond=>isUpcoming && myRsvp!=null && myRsvp!='organizer'
    && myRsvp!='left';

  factory OrbitPlan.fromJson(Map<String,dynamic> j) {
    final organizer=j['organizer'];
    final starts=j['starts_at'] is String
        ?DateTime.tryParse(j['starts_at'] as String):null;
    if(j['id'] is! String || j['title'] is! String || starts==null ||
        j['revision'] is! int || j['status'] is! String ||
        organizer is! Map || organizer['id'] is! String){
      throw const FormatException('Invalid Plan response.');
    }
    final raw=j['place'];
    final place=raw is Map?Map<String,dynamic>.from(raw):const <String,dynamic>{};
    final users=j['participants'];
    return OrbitPlan(id:j['id'] as String,title:j['title'] as String,
      description:j['description'] as String? ?? '',
      startsAt:starts.toLocal(),
      endsAt:j['ends_at'] is String?DateTime.tryParse(j['ends_at'] as String)?.toLocal():null,
      status:j['status'] as String,revision:j['revision'] as int,
      organizerId:organizer['id'] as String,
      organizerName:organizer['display_name'] as String? ?? 'Orbit member',
      myRsvp:j['my_rsvp'] as String?,canEdit:j['can_edit']==true,
      placeLabel:place['label'] as String?,placeRef:place['ref'] as String?,
      latitude:(place['latitude'] as num?)?.toDouble(),
      longitude:(place['longitude'] as num?)?.toDouble(),
      participants:users is List?users.map((item)=>OrbitPlanPerson.fromJson(
        Map<String,dynamic>.from(item as Map))).toList(growable:false):const []);
  }
}

class OrbitPlanPage {
  const OrbitPlanPage(this.items,this.nextCursor);
  final List<OrbitPlan> items;
  final String? nextCursor;
}

@immutable
class OrbitPlanReminderPreferences {
  const OrbitPlanReminderPreferences({
    required this.enabled,required this.offsets,required this.allowedOffsets});
  final bool enabled;
  final List<int> offsets,allowedOffsets;
  factory OrbitPlanReminderPreferences.fromJson(Map<String,dynamic> j) {
    final offsets=j['offsets_minutes'],allowed=j['allowed_offsets_minutes'];
    if(j['enabled'] is! bool || offsets is! List || allowed is! List ||
        offsets.any((x)=>x is! int)||allowed.any((x)=>x is! int)){
      throw const FormatException('Invalid Plan reminder settings.');
    }
    return OrbitPlanReminderPreferences(enabled:j['enabled'] as bool,
      offsets:List<int>.unmodifiable(offsets.cast<int>()),
      allowedOffsets:List<int>.unmodifiable(allowed.cast<int>()));
  }
}
