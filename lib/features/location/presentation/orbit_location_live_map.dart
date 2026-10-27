import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_circular_icon_button.dart';
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
    this.onMarkersChanged,this.onPersonPressed});
  final OrbitLocationRepository? repository;
  final OrbitLocationPermissionService? permissions;
  final ValueChanged<List<OrbitLocationMarker>>? onMarkersChanged;
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
  final Map<gl.Circle,String> _circleOwners={};
  StreamSubscription<Position>? _locations;
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
      _refreshTimer=Timer.periodic(const Duration(seconds:40),(_){
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
    unawaited(_locations?.cancel());
    _locations=null;
    WidgetsBinding.instance.removeObserver(this);
    _circleOwners.clear();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed) {
      _foreground=false;
      ++_epoch;
      _locations?.cancel();
      _locations=null;
      _lastSent=null;
      _cap=null;_snapshot=null;_shares=const [];
      unawaited(_clearAnnotations());
      _circleOwners.clear();
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
      await _syncAnnotations();
      await _syncGps();
    }catch(e){
      if(!mounted||serial!=_epoch)return;
      // Never keep old position grants after auth/revocation/network failure.
      _locations?.cancel();_locations=null;
      setState((){
        _cap=null;_shares=const [];_snapshot=null;
        _message=e is OrbitIdentityException && e.statusCode==404
          ? 'Location is not enabled on the server.'
          : 'Map access could not be verified. Reconnect and retry.';
      });
      widget.onMarkersChanged?.call(const []);
      await _clearAnnotations();
    }finally{_loading=false;}
  }

  Future<void> _clearAnnotations() async {
    final map=_map;
    if(map==null||!_styleReady)return;
    _circleOwners.clear();
    try{await map.clearCircles();}catch(_){}
  }
  void _onMapCreated(gl.MapLibreMapController controller){
    _map=controller;
    controller.onCircleTapped.add((circle){
      final user=_circleOwners[circle];
      if(user!=null&&mounted)widget.onPersonPressed?.call(user);
    });
  }
  Future<void> _syncAnnotations() async{
    final map=_map;
    if(map==null||!_styleReady||!mounted)return;
    try{
      await map.clearCircles();_circleOwners.clear();
      final markers=_snapshot?.markers??const <OrbitLocationMarker>[];
      if(markers.isEmpty)return;
      final circleOptions=markers.map((m)=>gl.CircleOptions(
        geometry:gl.LatLng(m.latitude,m.longitude),circleRadius:18,
        circleColor:'#7C3AED',circleStrokeWidth:3,
        circleStrokeColor:'#FFFFFF')).toList();
      final circles=await map.addCircles(circleOptions);
      if(!mounted)return;
      for(var i=0;i<circles.length&&i<markers.length;i++){
        _circleOwners[circles[i]]=markers[i].userId;
      }
      if(!_didZoom){
        _didZoom=true;
        await map.animateCamera(gl.CameraUpdate.newLatLngZoom(
          gl.LatLng(markers.first.latitude,markers.first.longitude),12));
      }
    }catch(_){
      // Map SDK failure cannot relax authorization or restore a stale pin.
      _circleOwners.clear();
      if(mounted)setState(()=>_message='Map pins could not be displayed. Refresh the map.');
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
    _sending=true;_lastSent=now;
    try {
      // A user switch cannot inherit another account's GPS stream or grants.
      final owner=await OrbitIdentityClient.instance.currentLocalSocialOwner();
      if(owner==null||owner!=_accountOwner){
        _locations?.cancel();_locations=null;
        if(mounted)await _refresh();
        return;
      }
      if(!await _gps.granted()){
        await _stopAfterPermissionFailure();return;
      }
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
        )
        :Image.asset('assets/orbit_map.png',fit:BoxFit.cover,
          semanticLabel:'Map preview, no live location data')),
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
