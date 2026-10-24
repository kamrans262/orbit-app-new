import 'package:flutter/material.dart';

import '../widgets/orbit_circle_confirmation.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_circle_repository.dart';

class OrbitLiveArchivedCirclesScreen extends StatefulWidget {
  const OrbitLiveArchivedCirclesScreen({super.key,this.repository});
  final OrbitCircleRepository? repository;
  @override
  State<OrbitLiveArchivedCirclesScreen> createState()=>_OrbitLiveArchivedCirclesScreenState();
}

class _OrbitLiveArchivedCirclesScreenState extends State<OrbitLiveArchivedCirclesScreen> {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  List<OrbitCircle> _circles=const [];
  bool _loading=true;
  String? _error;

  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(() {_loading=true;_error=null;});
    try {
      final circles=<OrbitCircle>[];
      for(var page=1;page<=20;page++){
        final response=await _repo.archived(page:page);
        circles.addAll(response.items);
        if(!response.hasMore)break;
      }
      if(mounted)setState(() {_circles=circles;_loading=false;});
    }catch(e){
      if(mounted)setState((){
        _circles=const [];
        _loading=false;
        _error=e is OrbitIdentityException && e.statusCode==404
          ? 'Circle restoration is not enabled on the server yet.'
          : 'Unable to verify archived Circles.';
      });
    }
  }

  Future<void> _restore(OrbitCircle circle) async {
    final confirmed=await showOrbitCircleConfirmation(
      context:context,
      title:'Restore Circle?',
      description:'Restore ${circle.name}? Sharing remains OFF, '
        'and previously revoked invitations will not become valid again.',
      confirmLabel:'Restore',
    );
    if(confirmed!=true)return;
    try{
      await _repo.restore(circle.id);
      if(mounted) await _load();
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e is OrbitIdentityException ? e.message :
          'Unable to restore Circle.')));
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Column(children:[
      const Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,0),
        child:AppScreenHeader(title:'Archived Circles'),
      ),
      const SizedBox(height:20),
      Expanded(child:_loading ? const Center(child:CircularProgressIndicator())
      : _error!=null ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(_error!,textAlign:TextAlign.center),
        TextButton(onPressed:_load,child:const Text('Try again')),
      ]))
      : _circles.isEmpty ? const Center(child:Text('No archived Circles.'))
      : ListView.builder(
          itemCount:_circles.length,padding:const EdgeInsets.all(20),
          itemBuilder:(context,index){
            final circle=_circles[index];
            return Card(color:Colors.white,elevation:0,
              child:ListTile(
                title:Text(circle.name,style:const TextStyle(
                  fontFamily:AppTypography.fontFamily,fontWeight:FontWeight.w600)),
                subtitle:const Text('Archived • private access paused'),
                trailing:TextButton(onPressed:()=>_restore(circle),
                  child:const Text('Restore')),
              ));
          }),
      ),
    ])),
  );
}
