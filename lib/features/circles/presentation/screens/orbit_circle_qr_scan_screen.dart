import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../data/orbit_circle_repository.dart';

/// QR scanning never admits a person. Caller must preview with authenticated
/// backend and explicitly confirm before joining the Circle.
class OrbitCircleQrScanScreen extends StatefulWidget {
  const OrbitCircleQrScanScreen({super.key,this.repository});
  final OrbitCircleRepository? repository;
  @override
  State<OrbitCircleQrScanScreen> createState()=>_OrbitCircleQrScanScreenState();
}

class _OrbitCircleQrScanScreenState extends State<OrbitCircleQrScanScreen> {
  late final OrbitCircleRepository _repo=widget.repository ?? OrbitCircleRepository();
  final MobileScannerController _camera=MobileScannerController(
    formats:<BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed:DetectionSpeed.noDuplicates,
  );
  bool _consumed=false;
  String? _error;

  void _read(BarcodeCapture detection){
    if(_consumed || !mounted)return;
    for(final code in detection.barcodes){
      final payload=code.rawValue;
      if(payload==null)continue;
      try{
        final value=_repo.validateCode(payload);
        _consumed=true;
        Navigator.of(context).pop(value);
        return;
      }on FormatException {
        setState(()=>_error='Not a valid private Orbit Circle invitation.');
      }
    }
  }
  @override
  void dispose(){_camera.dispose();super.dispose();}

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Column(children:[
      const Padding(padding:EdgeInsets.all(20),
        child:AppScreenHeader(title:'Scan Circle Invitation')),
      Expanded(child:Padding(padding:const EdgeInsets.all(20),
        child:ClipRRect(borderRadius:BorderRadius.circular(24),
          child:MobileScanner(controller:_camera,onDetect:_read,
            errorBuilder:(context,error)=>const Center(child:Padding(
              padding:EdgeInsets.all(16),
              child:Text('Camera access is unavailable. Enter the invitation code manually.')))),
        ))),
      if(_error!=null)Padding(padding:const EdgeInsets.all(12),
        child:Text(_error!,textAlign:TextAlign.center,
          style:const TextStyle(color:Color(0xFFB91C1C)))),
      const Padding(padding:EdgeInsets.fromLTRB(20,0,20,24),
        child:Text('Scanning only reads the invitation. '
          'You must confirm joining after the server verifies it.',
          textAlign:TextAlign.center)),
    ])),
  );
}
