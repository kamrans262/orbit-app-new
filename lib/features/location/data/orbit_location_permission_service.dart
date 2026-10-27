import 'package:geolocator/geolocator.dart';
/// Foreground-only GPS. Merely opening map never triggers permission.
class OrbitLocationPermissionService {
  const OrbitLocationPermissionService();
  Future<bool> granted({bool request=false}) async {
    if(!await Geolocator.isLocationServiceEnabled())return false;
    var p=await Geolocator.checkPermission();
    if(p==LocationPermission.denied&&request)p=await Geolocator.requestPermission();
    return p==LocationPermission.whileInUse||p==LocationPermission.always;
  }
  Future<bool> precise() async {
    try{return await Geolocator.getLocationAccuracy()==LocationAccuracyStatus.precise;}
    catch(_){return false;}
  }
  Stream<Position> foregroundStream()=>Geolocator.getPositionStream(
    locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:30));
  Future<Position> current()=>Geolocator.getCurrentPosition(
    locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,
      timeLimit:Duration(seconds:14)));
}
