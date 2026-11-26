/// An HTTPS reference carries only a Moment identifier, never access rights.
abstract final class OrbitMomentLink {
  static const host='indigo-caribou-178970.hostingersite.com';
  static final _uuid=RegExp(r'^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$');
  static Uri create(String id){
    if(!_uuid.hasMatch(id))throw const FormatException('Invalid Moment reference.');
    return Uri.https(host,'/moment/$id');
  }
  static String? parse(Uri uri){
    if(uri.userInfo.isNotEmpty||uri.hasPort||uri.hasQuery||uri.hasFragment)return null;
    final parts=uri.pathSegments;
    final String? id;
    if(uri.scheme=='https'&&uri.host==host&&parts.length==2&&parts.first=='moment'){
      id=parts.last;
    }else if(uri.scheme=='orbit'&&uri.host=='moment'&&parts.length==1){
      id=parts.single;
    }else{return null;}
    return _uuid.hasMatch(id)?id.toLowerCase():null;
  }
}
