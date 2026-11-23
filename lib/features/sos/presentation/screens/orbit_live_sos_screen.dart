import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/popups/orbit_popup_modal.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../../circles/data/orbit_circle_repository.dart';
import '../../../location/data/orbit_location_permission_service.dart';
import '../../data/orbit_sos_repository.dart';
import '../../domain/models/sos_models.dart';
import 'sos_alert_screen.dart';
import 'sos_responder_map_screen.dart';
import 'orbit_live_sos_contacts_screen.dart';
import 'orbit_live_sos_incident_screen.dart';
import 'orbit_live_sos_inbox_screen.dart';

/// Approved SOS hold-to-send screen with a real authenticated service bridge.
/// A three-second hold is the only initiator action that creates an incident.
class OrbitLiveSosScreen extends StatefulWidget {
  const OrbitLiveSosScreen({this.repository,this.locationService,super.key});
  final OrbitSosRepository? repository;
  final OrbitLocationPermissionService? locationService;
  @override
  State<OrbitLiveSosScreen> createState()=>_OrbitLiveSosScreenState();
}
class _OrbitLiveSosScreenState extends State<OrbitLiveSosScreen>
    with WidgetsBindingObserver {
  late final OrbitSosRepository _repo=widget.repository??OrbitSosRepository();
  late final OrbitLocationPermissionService _location=widget.locationService??
      const OrbitLocationPermissionService();
  String? _circleId,_owner;
  bool _shareLocation=false,_recordingConsent=false;
  OrbitSosIntent? _unconfirmed;
  bool _requestBusy=false;

  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_prepare());}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(_prepare());
    if(state==AppLifecycleState.paused || state==AppLifecycleState.hidden){
      if(mounted)setState((){_owner=null;_circleId=null;});
    }
  }
  Future<void> _prepare() async {
    try {
      final owner=await _repo.owner();
      final pending=await _repo.pending();
      String? circle;
      try{
        final primary=await OrbitCircleRepository().primary();
        circle=primary['circle_id'] as String?;
      }catch(_){}
      if(mounted && await OrbitIdentityClient.instance.currentLocalSocialOwner()==owner){
        setState((){_owner=owner;_circleId=circle;_unconfirmed=pending;});
      }
    }catch(_){if(mounted)setState((){_owner=null;_circleId=null;_unconfirmed=null;});}
  }

  void _notify(String text){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(text),duration:const Duration(seconds:7)));
  }

  Future<bool> _confirm({required String title,required String message,
      required String accept}) async {
    final value=await showOrbitPopupModal<bool>(context:context,
      builder:(dialog)=>OrbitPopupModal(title:title,description:message,
        primaryAction:OrbitPopupPrimaryButton(label:accept,
          onPressed:()=>Navigator.of(dialog).pop(true)),
        secondaryAction:OrbitPopupTextButton(label:'Not now',
          onPressed:()=>Navigator.of(dialog).pop(false))));
    return value==true;
  }

  Future<void> _chooseLocation() async {
    if(_shareLocation){setState(()=>_shareLocation=false);
      _notify('SOS location sharing is off.');return;}
    final consent=await _confirm(title:'Share location during SOS?',
      message:'Your fresh GPS location will be visible only to currently authorized SOS responders while the incident is active. You can disable it before starting SOS.',
      accept:'Allow SOS location');
    if(!consent||!mounted)return;
    try {
      if(!await _location.granted(request:true)){
        _notify('Location permission was not granted. SOS can still be sent without location.');return;
      }
      if(mounted)setState(()=>_shareLocation=true);
      _notify('SOS location enabled for the next alert. No location has been shared yet.');
    }catch(_){_notify('Location unavailable. You can still send SOS without location.');}
  }

  Future<void> _chooseRecording() async {
    if(_recordingConsent){setState(()=>_recordingConsent=false);
      _notify('Recording consent removed.');return;}
    final ok=await _confirm(title:'Emergency recording consent',
      message:'The SOS backend can store your consent, but audio capture and upload are not available. Enabling consent does not start recording.',
      accept:'Save consent only');
    if(ok && mounted){setState(()=>_recordingConsent=true);
      _notify('Consent saved for this SOS only. No audio is being recorded.');}
  }

  Future<void> _callEmergency() async {
    final controller=TextEditingController();
    final phone=await showOrbitPopupModal<String>(context:context,
      builder:(dialog)=>OrbitPopupModal(title:'Call emergency services',
        description:'Enter your local emergency number to open your phone dialer. Orbit does not place calls itself.',
        content:TextField(controller:controller,keyboardType:TextInputType.phone,
          maxLength:20,decoration:const InputDecoration(labelText:'Local emergency number')),
        primaryAction:OrbitPopupPrimaryButton(label:'Open dialer',onPressed:(){
          final value=controller.text.trim();
          if(RegExp(r'^\+?[0-9]{2,18}$').hasMatch(value)){
            Navigator.of(dialog).pop(value);
          }
        }),
        secondaryAction:OrbitPopupTextButton(label:'Cancel',
          onPressed:()=>Navigator.of(dialog).pop())));
    controller.dispose();
    if(phone==null||!mounted)return;
    try {
      if(!await launchUrl(Uri(scheme:'tel',path:phone),mode:LaunchMode.externalApplication)){
        _notify('Open your phone app and dial the local emergency number.');
      }
    }catch(_){_notify('Could not open dialer. Please call emergency services from your phone.');}
  }

  Future<void> _openContacts() async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveSosContactsScreen(repository:_repo)));
  }
  Future<void> _openInbox() async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveSosInboxScreen(repository:_repo)));
  }
  Future<void> _openIncident(SosResponderSession session) async {
    await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
      builder:(_)=>OrbitLiveSosIncidentScreen(incidentId:session.id,repository:_repo)));
  }

  Future<SosResponderSession?> _activate(SosAlertSubmission submitted) async {
    if(_requestBusy)return null;
    _requestBusy=true;
    try {
      if(submitted.heldFor<const Duration(seconds:3))return null;
      final owner=await _repo.owner();
      if(_owner!=null && owner!=_owner)throw OrbitIdentityException('Account changed.',401);
      double? lat,lng;
      DateTime? captured;
      bool withLocation=_shareLocation;
      if(withLocation){
        try{
          if(await _location.granted()){
            final sample=await _location.current();
            lat=sample.latitude;lng=sample.longitude;
            captured=sample.timestamp;
            if(captured==null || DateTime.now().difference(captured).inSeconds.abs()>100){
              withLocation=false;
            }
          }else{withLocation=false;}
        }catch(_){withLocation=false;}
        if(!withLocation){
          _notify('Could not obtain fresh GPS. Sending SOS without location.');
        }
      }
      // A pending ambiguous request must be reviewed before a new client_id
      // is generated, preventing duplicate incidents after a network timeout.
      final pending=await _repo.pending();
      if(pending!=null){
        if(mounted)setState(()=>_unconfirmed=pending);
        _notify('A previous SOS request is unconfirmed. Review it or retry using the same ID.');
        return null;
      }
      final result=await _repo.create(circleId:_circleId,shareLocation:withLocation,
        recordingConsent:_recordingConsent,latitude:lat,longitude:lng,
        capturedAt:captured);
      if(mounted)setState(()=>_unconfirmed=null);
      if(!result.serverAccepted)return null;
      return SosResponderSession(id:result.id,serverConfirmed:true,
        originatorName:'You',circleName:'Private SOS',status:result.status,
        responders:const [],deliveryLabel:result.deliveryDescription,
        recordingLabel:result.recordingDescription,
        locationLabel:result.locationActive?'SOS location sharing active':'No location shared');
    }catch(error){
      if(mounted){
        try{final stored=await _repo.pending();if(mounted)setState(()=>_unconfirmed=stored);}catch(_){}
        if(error is OrbitIdentityException && error.statusCode!=null){
          _notify('SOS request was rejected. No responder delivery is confirmed.');
        }else{
          _notify('SOS was not confirmed. It may have reached Orbit. Check SOS history before retrying.');
        }
      }
      return null;
    }finally{_requestBusy=false;}
  }

  Future<void> _retry() async {
    final intent=_unconfirmed;
    if(intent==null||_requestBusy)return;
    _requestBusy=true;
    try{
      if(!intent.locationFresh){
        _notify('The location sample expired. Check SOS history before starting a new alert.');
        return;
      }
      final incident=await _repo.retry(intent);
      if(!mounted)return;
      setState(()=>_unconfirmed=null);
      await Navigator.of(context).push<void>(AppFadeSlidePageRoute<void>(
        builder:(_)=>OrbitLiveSosIncidentScreen(incidentId:incident.id,repository:_repo)));
    }catch(_){_notify('SOS still not confirmed. Contact local emergency services directly if needed.');}
    finally{_requestBusy=false;}
  }

  Future<void> _discard() async {
    final ok=await _confirm(title:'Discard an unconfirmed SOS request?',
      message:'Orbit cannot determine whether the previous request reached the server. Check SOS history before starting another incident.',
      accept:'Discard local retry');
    if(!ok)return;
    await _repo.discardPending();
    if(mounted)setState(()=>_unconfirmed=null);
  }

  @override
  Widget build(BuildContext context)=>SosAlertScreen(
    onActivateSos:_activate,
    onConfirmedSession:_openIncident,
    onEmergencyContacts:()=>unawaited(_openContacts()),
    onShareLocation:()=>unawaited(_chooseLocation()),
    onRecordAudio:()=>unawaited(_chooseRecording()),
    onCallEmergency:()=>unawaited(_callEmergency()),
    onViewHistory:()=>unawaited(_openInbox()),
    shareLocationSelected:_shareLocation,
    recordingConsentSelected:_recordingConsent,
    pendingUnconfirmed:_unconfirmed!=null,
    onRetryPending:()=>unawaited(_retry()),
    onDiscardPending:()=>unawaited(_discard()),
  );
}
