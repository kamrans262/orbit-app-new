import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_sos_repository.dart';
import 'sos_responder_map_screen.dart';

/// Existing approved responder screen, backed by fresh, authorized API reads.
/// Coordinates never survive backgrounding, revocation or a changed account.
class OrbitLiveSosIncidentScreen extends StatefulWidget {
  const OrbitLiveSosIncidentScreen({required this.incidentId,this.repository,super.key});
  final String incidentId;
  final OrbitSosRepository? repository;
  @override
  State<OrbitLiveSosIncidentScreen> createState()=>_OrbitLiveSosIncidentScreenState();
}

class _OrbitLiveSosIncidentScreenState extends State<OrbitLiveSosIncidentScreen>
    with WidgetsBindingObserver {
  late final OrbitSosRepository _repo=widget.repository??OrbitSosRepository();
  OrbitSosIncident? _incident;
  OrbitSosLocation? _location;
  Timer? _timer;
  String? _owner;
  String? _error;
  int _epoch=0;
  bool _loading=true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _timer=Timer.periodic(const Duration(seconds:15),(_){
      if(mounted && WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent==true){unawaited(_refresh());}
    });
  }
  @override
  void dispose(){_epoch++;_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused || state==AppLifecycleState.hidden ||
        state==AppLifecycleState.inactive){
      ++_epoch;
      if(mounted)setState((){_location=null;_incident=null;_loading=true;});
    }else if(state==AppLifecycleState.resumed){unawaited(_refresh());}
  }

  Future<void> _refresh() async {
    final request=++_epoch;
    try {
      final owner=await _repo.owner();
      final incident=await _repo.incident(widget.incidentId);
      OrbitSosLocation? location;
      if(incident.status=='active' && incident.locationActive){
        try{location=await _repo.location(incident.id);}catch(_){location=null;}
      }
      if(!mounted||request!=_epoch ||
          await OrbitIdentityClient.instance.currentLocalSocialOwner()!=owner)return;
      setState((){_owner=owner;_incident=incident;_location=location;
        _error=null;_loading=false;});
    }catch(_) {
      if(!mounted||request!=_epoch)return;
      setState((){_location=null;_incident=null;_owner=null;
        _loading=false;_error='SOS status could not be verified. Reconnect and retry.';});
    }
  }

  Future<bool> _act(bool resolve) async {
    try {
      final owner=_owner;
      if(owner==null || await _repo.owner()!=owner)return false;
      final fresh=await _repo.incident(widget.incidentId);
      if(fresh.role!='initiator' || fresh.status!='active')return false;
      final updated=resolve
        ?await _repo.resolve(fresh.id,fresh.revision)
        :await _repo.cancel(fresh.id,fresh.revision);
      if(!mounted||await _repo.owner()!=owner)return false;
      setState((){_incident=updated;_location=null;});
      return updated.status==(resolve?'resolved':'cancelled');
    }catch(_){if(mounted)unawaited(_refresh());return false;}
  }

  Future<bool> _acknowledge() async {
    try{
      final owner=_owner;
      if(owner==null || await _repo.owner()!=owner)return false;
      final result=await _repo.acknowledge(widget.incidentId);
      if(!mounted||await _repo.owner()!=owner)return false;
      unawaited(_refresh());
      return result.role=='responder' && result.myResponse=='acknowledged';
    }catch(_){if(mounted)unawaited(_refresh());return false;}
  }

  SosResponderSession _toSession(OrbitSosIncident incident) {
    final records=incident.responders.map((r)=>SosResponderPerson(
      id:r.id,name:r.name,status:r.state=='acknowledged'
        ?'Acknowledged SOS':'Awaiting acknowledgement',
    )).toList(growable:false);
    return SosResponderSession(id:incident.id,serverConfirmed:incident.serverAccepted,
      originatorName:incident.role=='initiator'?'You':incident.initiatorName,
      circleName:'Private SOS',status:incident.status,
      responders:records,isOriginator:incident.role=='initiator',
      deliveryLabel:incident.deliveryDescription,
      recordingLabel:incident.recordingDescription,
      locationLabel:_location!=null ?'Shared location verified by SOS service'
        :incident.locationActive?'Location unavailable or access revoked':'No active location share');
  }

  @override
  Widget build(BuildContext context){
    final incident=_incident;
    if(_loading || incident==null){
      return Scaffold(backgroundColor:const Color(0xFF0D0F20),body:SafeArea(child:
        Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(_loading)const CircularProgressIndicator(),
          if(!_loading)...[
            const Icon(Icons.warning_amber_rounded,color:Colors.white70,size:34),
            const SizedBox(height:12),
            Padding(padding:const EdgeInsets.all(20),child:Text(_error??'Incident unavailable.',
              textAlign:TextAlign.center,style:const TextStyle(color:Colors.white))),
            TextButton(onPressed:_refresh,child:const Text('Retry')),
          ],
          TextButton(onPressed:()=>Navigator.of(context).maybePop(),child:const Text('Back')),
        ])),));
    }
    Widget? map;
    final loc=_location;
    if(loc!=null && incident.status=='active' && DateTime.now().isBefore(loc.expiresAt)){
      final target=LatLng(loc.latitude,loc.longitude);
      map=GoogleMap(
        key:ValueKey('sos-authorized-map-${incident.id}'),
        initialCameraPosition:CameraPosition(target:target,zoom:15),
        markers:{Marker(markerId:const MarkerId('authorized-sos-location'),position:target,
          infoWindow:const InfoWindow(title:'Shared SOS location'))},
        myLocationEnabled:false,myLocationButtonEnabled:false,
        zoomControlsEnabled:false,mapToolbarEnabled:false,
      );
    }
    return SosResponderMapScreen(
      session:_toSession(incident),liveMap:map,
      onResolve:incident.role=='initiator' && incident.status=='active'
        ?(_)=>_act(true):null,
      onCancel:incident.role=='initiator' && incident.status=='active'
        ?(_)=>_act(false):null,
      onEngage:incident.role=='responder' && incident.status=='active'
        ?(_)=>_acknowledge():null,
    );
  }
}
