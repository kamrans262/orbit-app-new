import '../../auth/data/orbit_identity_client.dart';

/// M14: private HTTPS inbox. Never persist private notification targets.
class OrbitNotificationItem {
  const OrbitNotificationItem({
    required this.id, required this.category, required this.type,
    required this.title, required this.body, required this.targetId,
    required this.createdAt, required this.read,
  });
  final String id, category, type, title, body, targetId;
  final DateTime createdAt;
  final bool read;

  static const categories = <String>{
    'moments','pings','check_ins','messages','friends','circles','security',
  };

  factory OrbitNotificationItem.fromJson(Map<String, dynamic> data) {
    String field(String key) {
      final v=data[key];
      if(v is! String || v.trim().isEmpty) {
        throw const FormatException('Invalid private notification response.');
      }
      return v;
    }
    final raw=data['target'];
    if(raw is! Map)throw const FormatException('Notification target unavailable.');
    final target=Map<String,dynamic>.from(raw);
    final category=field('category');
    final timestamp=DateTime.tryParse(field('created_at'));
    if(!categories.contains(category) || target['kind']!=category ||
       target['opaque_id'] is! String ||
       (target['opaque_id'] as String).isEmpty ||
       data['read'] is! bool || timestamp==null) {
      throw const FormatException('Notification metadata unavailable.');
    }
    return OrbitNotificationItem(
      id:field('id'),category:category,type:field('type'),
      title:field('title'),body:field('body'),
      targetId:target['opaque_id'] as String,createdAt:timestamp,
      read:data['read'] as bool);
  }
}
class OrbitNotificationPage {
  const OrbitNotificationPage(this.items,this.nextCursor);
  final List<OrbitNotificationItem> items;
  final String? nextCursor;
}
class OrbitNotificationPushBootstrap {
  const OrbitNotificationPushBootstrap(this.enabled,this.options);
  final bool enabled;
  final Map<String,dynamic> options;
}
class OrbitNotificationRepository {
  OrbitNotificationRepository({OrbitIdentityClient? identity})
      : _identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

  Future<String> _owner() async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null||owner.isEmpty) {
      throw OrbitIdentityException('Sign in to view notifications.',401);
    }
    return owner;
  }
  Future<Map<String,dynamic>> _request(String method,String path,
      {Map<String,Object?>? body}) async {
    final owner=await _owner();
    final response=await _identity.socialRequest(method,path,body:body);
    if(await _identity.currentLocalSocialOwner()!=owner){
      throw OrbitIdentityException('Account changed. Reload notifications.',401);
    }
    final data=response['data'];
    if(data is! Map)throw const FormatException('Invalid notification response.');
    return Map<String,dynamic>.from(data);
  }
  Future<OrbitNotificationPage> page({int limit=20,String? cursor,
      String? category}) async {
    final query=<String,String>{'limit':'$limit'};
    if(cursor!=null&&cursor.isNotEmpty)query['cursor']=cursor;
    if(category!=null&&category.isNotEmpty)query['category']=category;
    final path=Uri(path:'/me/notifications',queryParameters:query).toString();
    final data=await _request('GET',path);
    final list=data['items'];
    if(list is! List)throw const FormatException('Invalid notification list.');
    final items=list.map((item){
      if(item is! Map)throw const FormatException('Invalid notification row.');
      return OrbitNotificationItem.fromJson(Map<String,dynamic>.from(item));
    }).toList(growable:false);
    return OrbitNotificationPage(items,data['next_cursor'] as String?);
  }
  Future<int> unread() async {
    final result=await _request('GET','/me/notifications/unread');
    final count=result['count'];
    if(count is! int||count<0)throw const FormatException('Invalid unread count.');
    return count;
  }
  Future<void> markRead(String id) async {
    final owner=await _owner();
    await _identity.socialRequest('POST',
      '/me/notifications/' + Uri.encodeComponent(id) + '/read');
    if(await _identity.currentLocalSocialOwner()!=owner){
      throw OrbitIdentityException('Account changed. Retry.',401);
    }
  }
  Future<int> markAllRead({String? category}) async {
    final data=await _request('POST','/me/notifications/read-all',
      body:{if(category!=null)'category':category});
    final count=data['updated_count'];
    if(count is! int||count<0)throw const FormatException('Invalid acknowledgement.');
    return count;
  }
  Future<OrbitNotificationPushBootstrap> pushBootstrap() async {
    final data=await _request('GET','/me/notifications/push-bootstrap');
    if(data['enabled']!=true){
      return const OrbitNotificationPushBootstrap(false,{});
    }
    final options=data['options'];
    if(options is! Map)throw const FormatException('Push configuration missing.');
    return OrbitNotificationPushBootstrap(
      true,Map<String,dynamic>.from(options));
  }
  Future<void> registerDevice(String token,String platform) async {
    await _request('POST','/me/notifications/push-devices',
      body:{'token':token,'platform':platform});
  }
  Future<void> unregisterCurrentDevice() async {
    final owner=await _owner();
    await _identity.socialRequest('DELETE',
      '/me/notifications/push-devices/current');
    if(await _identity.currentLocalSocialOwner()!=owner){
      throw OrbitIdentityException('Account changed. Retry.',401);
    }
  }
}
