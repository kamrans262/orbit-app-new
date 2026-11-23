import '../../auth/data/orbit_identity_client.dart';

/// M18 returns only minimal source pointers, never content grants or media.
class OrbitActivityItem {
  const OrbitActivityItem({
    required this.id, required this.kind, required this.sourceType,
    required this.sourceId, required this.sourceRevision,
    required this.occurredAt,
  });
  final String id, kind, sourceType, sourceId;
  final int sourceRevision;
  final DateTime occurredAt;

  static final RegExp _uuid=RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive:false);
  static bool validId(Object? value) =>
      value is String && _uuid.hasMatch(value);

  factory OrbitActivityItem.fromJson(Map<String,dynamic> value) {
    final raw=value['source'];
    if(raw is! Map)throw const FormatException('Invalid Activity source.');
    final source=Map<String,dynamic>.from(raw);
    final type=source['type'];
    final expected= switch(type) {
      'moment'=>'moment.published',
      'check_in'=>'check_in.published',
      _=>null,
    };
    final timestamp=value['occurred_at'];
    final stamp=timestamp is String
        ? DateTime.tryParse(RegExp(r'(Z|[+-]\d\d:\d\d)$')
            .hasMatch(timestamp) ? timestamp : timestamp+'Z') : null;
    final revision=value['source_revision'];
    if(!validId(value['id']) || !validId(source['id']) ||
       expected==null || value['kind']!=expected ||
       stamp==null || revision is! int || revision<1) {
      throw const FormatException('Unsupported Activity pointer.');
    }
    return OrbitActivityItem(
      id:value['id'] as String,kind:expected,
      sourceType:type as String,sourceId:source['id'] as String,
      sourceRevision:revision,occurredAt:stamp.toUtc());
  }
}

class OrbitActivityCapabilities {
  const OrbitActivityCapabilities(this.available,this.moments,this.checkIns);
  final bool available,moments,checkIns;
  factory OrbitActivityCapabilities.fromJson(Map<String,dynamic> value){
    final sources=value['sources'];
    if(value['available'] is! bool ||
       value['sync_mode']!='authoritative_refresh' ||
       sources is! Map || sources['moment'] is! bool ||
       sources['check_in'] is! bool) {
      throw const FormatException('Invalid Activity capabilities.');
    }
    return OrbitActivityCapabilities(value['available'] as bool,
      sources['moment'] as bool,sources['check_in'] as bool);
  }
}

class OrbitActivityPage {
  const OrbitActivityPage(this.items,this.nextCursor);
  final List<OrbitActivityItem> items;
  final String? nextCursor;
  factory OrbitActivityPage.fromJson(Map<String,dynamic> value) {
    final rows=value['items'];
    if(rows is! List || rows.length>30 ||
       value['sync_mode']!='authoritative_refresh' ||
       (value['next_cursor']!=null && value['next_cursor'] is! String)) {
      throw const FormatException('Invalid Activity page.');
    }
    return OrbitActivityPage(
      rows.map((row){
        if(row is! Map)throw const FormatException('Malformed Activity row.');
        return OrbitActivityItem.fromJson(Map<String,dynamic>.from(row));
      }).toList(growable:false),value['next_cursor'] as String?);
  }
}

/// Foreground-only and memory-only. Every HTTP response is owner-bound.
/// Rendering still requires separate M7/M12 source reauthorization.
class OrbitActivityRepository {
  OrbitActivityRepository({OrbitIdentityClient? identity})
      :_identity=identity??OrbitIdentityClient.instance;
  final OrbitIdentityClient _identity;

  Future<Map<String,dynamic>> _data(String path) async {
    final owner=await _identity.currentLocalSocialOwner();
    if(owner==null || owner.isEmpty){
      throw OrbitIdentityException('Sign in to view Activity.',401);
    }
    final response=await _identity.socialRequest('GET',path);
    if(await _identity.currentLocalSocialOwner()!=owner){
      throw OrbitIdentityException('Account changed during Activity load.',409);
    }
    final value=response['data'];
    if(value is! Map)throw const FormatException('Invalid Activity envelope.');
    return Map<String,dynamic>.from(value);
  }

  Future<OrbitActivityCapabilities> capabilities() async =>
    OrbitActivityCapabilities.fromJson(await _data('/activity/capabilities'));

  Future<bool> requiresRefresh() async {
    final value=await _data('/activity/changes');
    if(value['sync_mode']!='authoritative_refresh' ||
       value['reset_required']!=true){
      throw const FormatException('Activity refresh contract not supported.');
    }
    return true;
  }

  Future<OrbitActivityPage> page({int limit=20,String? cursor}) async {
    if(limit<1||limit>30)throw ArgumentError.value(limit,'limit');
    if(cursor!=null && (cursor.isEmpty||cursor.length>500)){
      throw ArgumentError.value(cursor,'cursor');
    }
    final query=Uri(queryParameters:{
      'limit':'$limit',if(cursor!=null)'cursor':cursor,
    }).query;
    return OrbitActivityPage.fromJson(
      await _data('/activity/feed?'+query));
  }

  Future<OrbitActivityItem> item(String id) async {
    if(!OrbitActivityItem.validId(id))throw ArgumentError.value(id,'id');
    return OrbitActivityItem.fromJson(
      await _data('/activity/items/'+Uri.encodeComponent(id)));
  }

  /// Bound eight pages; cursors are never persisted or reused across accounts.
  Future<List<OrbitActivityItem>> currentPointers({int maximum=30}) async {
    if(maximum<1||maximum>240)throw ArgumentError.value(maximum,'maximum');
    final items=<OrbitActivityItem>[],seen=<String>{};
    String? cursor;
    for(var pass=0;pass<8&&items.length<maximum;pass++){
      final page=await this.page(
        limit:(maximum-items.length).clamp(1,30),cursor:cursor);
      for(final item in page.items){
        if(seen.add(item.id))items.add(item);
        if(items.length>=maximum)break;
      }
      if(page.nextCursor==null||page.nextCursor==cursor)break;
      cursor=page.nextCursor;
    }
    return List<OrbitActivityItem>.unmodifiable(items);
  }
}
