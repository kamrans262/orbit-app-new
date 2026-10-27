import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_circular_icon_button.dart';
import '../../orbit/domain/models/orbit_models.dart';
import '../../orbit/presentation/widgets/orbit_map_marker.dart';
import '../../media/data/orbit_media_repository.dart';
import '../../media/data/orbit_media_crypto.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../circles/presentation/widgets/orbit_circle_confirmation.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../profile/presentation/screens/orbit_preferences_screens.dart';
import '../data/orbit_location_models.dart';
import '../data/orbit_location_permission_service.dart';
import '../data/orbit_location_repository.dart';
import '../data/orbit_m10_rollout.dart';
import 'orbit_location_share_sheet.dart';

/// Placed inside the EXISTING Orbits screen, behind its existing draggable panel.
/// Markers are ONLY the M10 server's viewer-authorized projection, never demos.
class OrbitLocationLiveMap extends StatefulWidget {
  const OrbitLocationLiveMap({super.key,this.repository,this.permissions,
    this.onMarkersChanged,this.onPersonPressed,this.onAvatarsChanged});
  final OrbitLocationRepository? repository;
  final OrbitLocationPermissionService? permissions;
  final ValueChanged<List<OrbitLocationMarker>>? onMarkersChanged;
  final ValueChanged<Map<String,Uint8List>>? onAvatarsChanged;
  final ValueChanged<String>? onPersonPressed;
  @override
  State<OrbitLocationLiveMap> createState()=>_OrbitLocationLiveMapState();
}
class _OrbitLocationLiveMapState extends State<OrbitLocationLiveMap>
    with WidgetsBindingObserver {
  late final OrbitLocationRepository _repo=widget.repository??OrbitLocationRepository();
  late final OrbitLocationPermissionService _gps=widget.permissions??const OrbitLocationPermissionService();
  OrbitLocationCapabilities? _cap;
  OrbitLocationMapSnapshot? _snapshot;
  List<OrbitLocationShare> _shares=const [];
  gl.MapLibreMapController? _map;
  final Map<String,Uint8List> _avatarBytes={};
  final Map<String,String> _avatarMediaIds={};
  List<_OrbitPinGroup> _pinGroups=const [];
  int _projectSerial=0;
  final OrbitMediaRepository _media=OrbitMediaRepository();
  StreamSubscription<Position>? _locations;
  WebSocketChannel? _realtime;
  StreamSubscription<dynamic>? _realtimeEvents;
  Timer? _ticketExpiry;
  int _wsSerial=0;
  Timer? _refreshTimer;
  bool _styleReady=false,_loading=false,_sending=false,_foreground=true,_didZoom=false;
  DateTime? _lastSent;
  String? _accountOwner;
  int _epoch=0;
  String? _message;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if(OrbitM10Rollout.enabled) {
      unawaited(_refresh());
      _refreshTimer=Timer.periodic(const Duration(seconds:20),(_){
        if(_foreground&&mounted&&ModalRoute.of(context)?.isCurrent==true) {
          unawaited(_refresh(silent:true));
        }
      });
    }
  }

  @override
  void dispose(){
    ++_epoch;
    _refreshTimer?.cancel();
    _dropRealtime();
    unawaited(_locations?.cancel());
    _locations=null;
    WidgetsBinding.instance.removeObserver(this);
    _purgeAvatars(notify:false);_pinGroups=const [];
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed) {
      _foreground=false;
      ++_epoch;
      _locations?.cancel();
      _locations=null;
      _dropRealtime();
      _lastSent=null;
      _cap=null;_snapshot=null;_shares=const [];
      unawaited(_clearAnnotations());
      _purgeAvatars();
      _map=null;_styleReady=false;_didZoom=false;
      if(mounted){widget.onMarkersChanged?.call(const []);setState(() {});}
    } else {
      _foreground=true;
      unawaited(_refresh());
    }
  }

  bool get _active => _cap?.global.canShare==true && _shares.any((s)=>s.active);
  Future<void> _refresh({bool silent=false}) async{
    if(!OrbitM10Rollout.enabled||_loading||!_foreground)return;
    _loading=true;
    final serial=++_epoch;
    if(!silent&&mounted)setState(()=>_message=null);
    try{
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null||owner.isEmpty)throw const FormatException('Sign in to view Orbits.');
      if(_accountOwner!=owner){
        _accountOwner=owner;
        _locations?.cancel();_locations=null;_lastSent=null;
        _snapshot=null;_shares=const [];_cap=null;
        widget.onMarkersChanged?.call(const []);
        _purgeAvatars();
        await _clearAnnotations();
        if(mounted)setState((){});
      }
      final cap=await _repo.capabilities();
      final shares=await _repo.shares();
      final snapshot=await _repo.map();
      if(!mounted||serial!=_epoch||!_foreground)return;
      setState((){
        _cap=cap;_shares=shares;_snapshot=snapshot;_message=null;
      });
      widget.onMarkersChanged?.call(snapshot.markers);
      // Never carry one viewer's photo or media id into the next authorized snapshot.
      final mediaIds={for(final m in snapshot.markers)
        if(m.avatarMediaId!=null)m.userId:m.avatarMediaId!};
      for(final id in _avatarBytes.keys.toList()){
        if(_avatarMediaIds[id]!=mediaIds[id]){
          final old=_avatarBytes.remove(id);
          _avatarMediaIds.remove(id);
          if(old!=null)unawaited(MemoryImage(old).evict());
        }
      }
      widget.onAvatarsChanged?.call(Map.unmodifiable(_avatarBytes));
      await _syncAnnotations();
      unawaited(_loadAuthorizedAvatars(serial));
      await _syncGps();
      unawaited(_syncRealtime());
    }catch(e){
      if(!mounted||serial!=_epoch)return;
      // Never keep old position grants after auth/revocation/network failure.
      _locations?.cancel();_locations=null;
      _dropRealtime();
      setState((){
        _cap=null;_shares=const [];_snapshot=null;
        _message=e is OrbitIdentityException && e.statusCode==404
          ? 'Location is not enabled on the server.'
          : 'Map access could not be verified. Reconnect and retry.';
      });
      widget.onMarkersChanged?.call(const []);
      _purgeAvatars();
      await _clearAnnotations();
    }finally{_loading=false;}
  }

  void _purgeAvatars({bool notify=true}) {
    for(final bytes in _avatarBytes.values){
      unawaited(MemoryImage(bytes).evict()); // Flutter decoded-image cache.
    }
    _avatarBytes.clear();
    _avatarMediaIds.clear();
    if(notify&&mounted)widget.onAvatarsChanged?.call(const {});
  }

  Future<void> _clearAnnotations() async {
    ++_projectSerial;
    if(mounted)setState(()=>_pinGroups=const []);
  }
  void _onMapCreated(gl.MapLibreMapController controller) {
    _map=controller;
    unawaited(_syncAnnotations());
  }

  // Uses the existing Flutter OrbitMapMarker widgets over MapLibre so real
  // private M6 photo bytes never enter third-party tile providers.
  Future<void> _syncAnnotations() async {
    final map=_map;
    if(map==null||!_styleReady||!mounted||!_foreground)return;
    final serial=++_projectSerial;
    final markers=_snapshot?.markers??const <OrbitLocationMarker>[];
    if(markers.isEmpty){
      if(mounted)setState(()=>_pinGroups=const []);
      return;
    }
    try{
      if(!_didZoom){
        _didZoom=true;
        await map.animateCamera(gl.CameraUpdate.newLatLngZoom(
          gl.LatLng(markers.first.latitude,markers.first.longitude),12));
      }
      final points=await Future.wait(markers.map((p)=>
        map.toScreenLocation(gl.LatLng(p.latitude,p.longitude))));
      if(!mounted||serial!=_projectSerial||!_foreground)return;
      final groups=<_OrbitPinGroup>[];
      for(var i=0;i<markers.length;i++){
        final px=points[i].x.toDouble(),py=points[i].y.toDouble();
        if(!px.isFinite||!py.isFinite)continue;
        // Cluster after projection, not by world-coordinate distance.
        final existing=groups.indexWhere((group)=>
          math.sqrt(math.pow(group.x-px,2)+math.pow(group.y-py,2))<58);
        if(existing>=0){
          groups[existing].add(markers[i],px,py);
        }else{
          groups.add(_OrbitPinGroup(markers[i],px,py));
        }
      }
      if(mounted&&serial==_projectSerial)setState(()=>_pinGroups=groups);
    }catch(_){
      if(mounted)setState(()=>_pinGroups=const []);
    }
  }
  Future<void> _loadAuthorizedAvatars(int serial) async{
    final markers=_snapshot?.markers??const <OrbitLocationMarker>[];
    final withGrant=markers.where((m)=>m.avatarMediaId!=null).take(40).toList();
    if(withGrant.isEmpty)return;
    try{
      final trusted=await OrbitIdentityClient.instance.trustedMediaDevice();
      for(final m in withGrant){
        if(!mounted||!_foreground||serial!=_epoch)return;
        if(_avatarBytes.containsKey(m.userId))continue;
        try{
          final image=await _media.downloadPhoto(m.avatarMediaId!,
            deviceId:trusted.id,privateKey:trusted.privateKey,
            publicKey:trusted.publicKey,
            maxPlainBytes:OrbitMediaFormat.imageLimit);
          // A revoked marker or mismatched grant cannot outlive the request.
          if(!mounted||!_foreground||serial!=_epoch)return;
          if(!(_snapshot?.markers.any((x)=>x.userId==m.userId&&
            x.avatarMediaId==m.avatarMediaId)??false))continue;
          _avatarBytes[m.userId]=image;
          _avatarMediaIds[m.userId]=m.avatarMediaId!;
          widget.onAvatarsChanged?.call(Map.unmodifiable(_avatarBytes));
          setState((){});
        }catch(_){
          // Owner-only encrypted media or revoked grant -> existing initials.
        }
      }
    }catch(_){}
  }

  void _dropRealtime() {
    ++_wsSerial;
    _ticketExpiry?.cancel();_ticketExpiry=null;
    _realtimeEvents?.cancel();_realtimeEvents=null;
    _realtime?.sink.close();_realtime=null;
  }
  Future<void> _syncRealtime() async {
    if(!mounted||!_foreground||_cap?.realtimeAvailable!=true||
       !OrbitM10Rollout.realtimeConfigured){
      _dropRealtime();return;
    }
    if(_realtime!=null)return;
    final serial=++_wsSerial;
    try{
      final info=await _repo.realtimeTicket();
      if(!mounted||!_foreground||serial!=_wsSerial)return;
      // WSS host is deployment-approved. Never accept arbitrary backend URL.
      if(info['url']!=OrbitM10Rollout.realtimeSocketUrl)return;
      final socket=WebSocketChannel.connect(Uri.parse(OrbitM10Rollout.realtimeSocketUrl));
      _realtime=socket;
      await socket.ready.timeout(const Duration(seconds:7));
      if(!mounted||!_foreground||serial!=_wsSerial){
        socket.sink.close();return;
      }
      // Ticket is sent as the first message over TLS, never in the URL/log.
      socket.sink.add(jsonEncode({'type':'subscribe','ticket':info['ticket']}));
      _realtimeEvents=socket.stream.listen((raw){
        if(!mounted||!_foreground||serial!=_wsSerial)return;
        try{
          final event=jsonDecode(raw as String);
          if(event is Map && event['v']==1 &&
             event['type']=='location.invalidated') {
            // Never trust GPS within a socket event. Always reauthorize REST.
            unawaited(_refresh());
          }
        }catch(_){}
      },onError:(_){
        if(mounted&&serial==_wsSerial)_dropRealtime();
      },onDone:(){
        if(mounted&&serial==_wsSerial)_dropRealtime();
      });
      // Server tickets expire at 60s. Explicitly renew on the next refresh.
      _ticketExpiry=Timer(const Duration(seconds:48),(){
        if(!mounted||serial!=_wsSerial)return;
        _dropRealtime();unawaited(_syncRealtime());
      });
    }catch(_){
      if(mounted&&serial==_wsSerial)_dropRealtime();
      // Preserve the safe 20s authorized REST refresh fallback.
    }
  }

  Future<void> _syncGps() async{
    if(!_foreground||!_active){
      _locations?.cancel();_locations=null;return;
    }
    try{
      if(!await _gps.granted()){
        await _stopAfterPermissionFailure();return;
      }
      if(_locations!=null)return; // Recheck permission even with a running stream.
      unawaited(_gps.current().then(_sendPosition).catchError((Object _){
        // A GPS timeout does not grant permission or imply an update.
      }));
      _locations=_gps.foregroundStream().listen((position){
        unawaited(_sendPosition(position));
      },onError:(Object _){
        unawaited(_stopAfterPermissionFailure());
      },cancelOnError:true);
    }catch(_){await _stopAfterPermissionFailure();}
  }

  Future<void> _stopAfterPermissionFailure() async{
    _locations?.cancel();_locations=null;
    try{await _repo.stopAll();}catch(_){}
    if(mounted)await _refresh();
  }

  Future<void> _sendPosition(Position p) async{
    if(!_foreground||!mounted||!_active||_sending)return;
    final now=DateTime.now();
    if(_lastSent!=null&&now.difference(_lastSent!).inSeconds<24)return;
    if(!p.latitude.isFinite||!p.longitude.isFinite||!p.accuracy.isFinite||
       p.accuracy<0||p.accuracy>500)return;
    if(p.timestamp.isAfter(now.add(const Duration(seconds:15)))||
       now.difference(p.timestamp)>const Duration(seconds:90))return;
    final sampleEpoch=_epoch;
    _sending=true;_lastSent=now;
    try {
      // A user switch cannot inherit another account's GPS stream or grants.
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(!mounted||!_foreground||sampleEpoch!=_epoch||!_active)return;
      if(owner==null||owner!=_accountOwner){
        _locations?.cancel();_locations=null;
        if(mounted)await _refresh();
        return;
      }
      if(!await _gps.granted()){
        if(mounted&&_foreground)await _stopAfterPermissionFailure();
        return;
      }
      // Permission/lifecycle/account changes while awaiting OS APIs are a veto.
      if(!mounted||!_foreground||sampleEpoch!=_epoch||!_active)return;
      final accepted=await _repo.sample(latitude:p.latitude,longitude:p.longitude,
        accuracy:p.accuracy,observedAt:p.timestamp,heading:p.heading,speed:p.speed);
      if(!accepted&&mounted)await _refresh();
    }on OrbitIdentityException catch(e){
      if(e.statusCode==401||e.statusCode==403||e.statusCode==404||e.statusCode==409){
        _locations?.cancel();_locations=null;
        if(mounted)await _refresh();
      }
    }catch(_){
      // Network failure is not interpreted as proof that GPS was delivered.
    }finally{_sending=false;}
  }

  Future<void> _share() async {
    if(!mounted)return;
    var cap=_cap;
    if(cap==null){await _refresh();cap=_cap;}
    if(!mounted||cap==null)return;
    if(!cap.global.canShare){
      setState(()=>_message='Set location visibility and turn off Ghost Mode in Privacy Settings first.');
      return;
    }
    final success=await showOrbitLocationShareSheet(context:context,
      repository:_repo,capabilities:cap);
    if(success==true&&mounted)await _refresh();
  }
  Future<void> _privacy() async{
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder:(_)=>const OrbitPrivacyPreferencesScreen()));
    if(mounted)await _refresh();
  }
  Future<void> _stop() async{
    final approved=await showOrbitCircleConfirmation(context:context,
      title:'Stop sharing location?',
      description:'Revoke all active person and Circle grants and stop GPS updates on this device.',
      confirmLabel:'Stop sharing',destructive:true);
    if(!approved||!mounted)return;
    _locations?.cancel();_locations=null;
    try{await _repo.stopAll();}catch(_){
      if(mounted)setState(()=>_message='Could not confirm revocation. Please reconnect and retry.');
    }
    if(mounted)await _refresh();
  }
  Future<void> _manage() async{
    if(_shares.isEmpty)return;
    await showOrbitCircleSheet<void>(context:context,title:'Location sharing',
      builder:(sheet)=>Column(mainAxisSize:MainAxisSize.min,children:[
        for(final s in _shares.where((x)=>x.active))
          Padding(padding:const EdgeInsets.only(bottom:10),child:
            OrbitCircleSheetAction(title:'Stop '+s.audienceType+' · '+s.precision+
              (s.expiresAt==null?' · Manual stop':' · Timed'),
              icon:Icons.location_off_outlined,destructive:true,onTap:()async{
                final accepted=await showOrbitCircleConfirmation(context:sheet,
                  title:'Revoke sharing?',description:'Stop this location audience now?',
                  confirmLabel:'Revoke',destructive:true);
                if(!accepted)return;
                try{await _repo.revoke(s.id);}
                catch(_){if(sheet.mounted)ScaffoldMessenger.of(sheet).showSnackBar(
                  const SnackBar(content:Text('Unable to confirm revocation.')));return;}
                if(sheet.mounted)Navigator.of(sheet).pop();
              })),
      ]));
    if(mounted)await _refresh();
  }

  @override
  Widget build(BuildContext context){
    final configured=OrbitM10Rollout.mapConfigured;
    final markers=_snapshot?.markers??const <OrbitLocationMarker>[];
    final subtitle= !OrbitM10Rollout.enabled?'Location is not enabled for this build.'
      :_message??(!configured?'Map tiles awaiting provider configuration.'
      :markers.isEmpty?'No authorized location updates to show.'
      :'Last confirmed locations · not live');
    return Stack(children:[
      Positioned.fill(child:!_foreground
        ?const ColoredBox(color:AppColors.background)
        :configured&&OrbitM10Rollout.enabled
        ?gl.MapLibreMap(
          key:const Key('orbit_map'),styleString:OrbitM10Rollout.mapStyleUrl,
          initialCameraPosition:const gl.CameraPosition(target:gl.LatLng(0,0),zoom:1.7),
          onMapCreated:_onMapCreated,
          onStyleLoadedCallback:(){_styleReady=true;unawaited(_syncAnnotations());},
          onCameraIdle:()=>unawaited(_syncAnnotations()),
        )
        :Image.asset('assets/orbit_map.png',fit:BoxFit.cover,
          semanticLabel:'Map preview, no live location data')),
      // Render the original Orbit avatar component at authorized coordinates.
      // Never synthesize profile photos or reveal names for absent records.
      if(_foreground && _styleReady && configured && OrbitM10Rollout.enabled)
        ..._pinGroups.map((group)=>Positioned(
          left:group.x-24,top:group.y-24,
          child:group.members.length==1
            ?Tooltip(
              message:(group.members.first.displayName??'Orbit member')+
                ' · '+group.members.first.freshness,
              child:OrbitMapMarker(
                person:OrbitPersonData(id:group.members.first.userId,
                  name:group.members.first.displayName??'Orbit member',
                  imagePath:null,markerX:0,markerY:0,
                  imageBytes:_avatarBytes[group.members.first.userId]),
                onTap:()=>widget.onPersonPressed?.call(group.members.first.userId)))
            :Semantics(label:'Location cluster of '+group.members.length.toString()+
                ' people',button:true,
              child:Material(shape:const CircleBorder(),color:AppColors.primaryEnd,
                elevation:3,child:InkWell(customBorder:const CircleBorder(),
                onTap:()=>_map?.animateCamera(gl.CameraUpdate.zoomIn()),
                child:SizedBox(width:46,height:46,child:Center(
                  child:Text(group.members.length.toString(),
                    style:const TextStyle(fontFamily:AppTypography.fontFamily,
                      color:Colors.white,fontWeight:FontWeight.w700))))))),
        )),
      Positioned(left:15,right:15,top:42,child:Row(children:[
        Expanded(child:DecoratedBox(decoration:BoxDecoration(color:AppColors.white,
          borderRadius:BorderRadius.circular(30)),
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
            child:Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontFamily:AppTypography.fontFamily,
                fontSize:11,color:AppColors.textMuted))))),
        const SizedBox(width:8),
        AppCircularIconButton(icon:Icons.refresh_rounded,
          iconGradient:AppColors.primaryGradient,semanticLabel:'Refresh authorized map',
          onPressed:()=>unawaited(_refresh())),
        const SizedBox(width:8),
        AppCircularIconButton(icon:Icons.privacy_tip_outlined,
          iconGradient:AppColors.primaryGradient,semanticLabel:'Location privacy settings',
          onPressed:()=>unawaited(_privacy())),
        const SizedBox(width:8),
        AppCircularIconButton(icon:Icons.add_location_alt_outlined,
          iconGradient:AppColors.primaryGradient,semanticLabel:'Share location',
          onPressed:()=>unawaited(_share())),
      ])),
      if(_active)Positioned(top:105,right:15,child:Row(children:[
        TextButton.icon(onPressed:()=>unawaited(_manage()),
          icon:const Icon(Icons.group_outlined,size:17),
          label:Text('Sharing · '+_shares.where((s)=>s.active).length.toString())),
        TextButton.icon(onPressed:()=>unawaited(_stop()),
          icon:const Icon(Icons.location_off_outlined,size:17),
          label:const Text('Stop')),
      ])),
    ]);
  }
}

class _OrbitPinGroup {
  _OrbitPinGroup(OrbitLocationMarker marker,this.x,this.y):members=[marker];
  final List<OrbitLocationMarker> members;
  double x,y;
  void add(OrbitLocationMarker marker,double px,double py) {
    final count=members.length;
    x=(x*count+px)/(count+1);
    y=(y*count+py)/(count+1);
    members.add(marker);
  }
}
