import '../../config/data/orbit_public_config_runtime.dart';

/// Approved local editing availability only; never access or entitlement.
class OrbitCameraToolCatalog {
  const OrbitCameraToolCatalog._(this.filters,this.stickers);
  static const approvedFilters=<String>['natural','warm','cool','portrait','film','night','soft','vibrant','blackAndWhite'];
  static const approvedStickers=<String>['❤️','😂','😍','🔥','🎉','⭐','🌸','💖','👍','👑','🌈','✨'];
  final List<String> filters,stickers;
  static const baseline=OrbitCameraToolCatalog._(approvedFilters,approvedStickers);
  static const restricted=OrbitCameraToolCatalog._(<String>['natural'],<String>[]);
  static OrbitCameraToolCatalog get current=>fromHints(OrbitPublicConfigRuntime.instance.cameraToolHints);
  static OrbitCameraToolCatalog fromHints(Object? raw){
    if(raw==null)return baseline;
    if(raw is! Map||raw['schema_version']!=1||raw['revision'] is! int||(raw['revision'] as int)<1)return restricted;
    final filters=raw['filters'],stickers=raw['stickers'];
    bool valid(Object? values,List<String> allowed)=>values is List&&values.length<=allowed.length&&
      values.every((v)=>v is String&&allowed.contains(v))&&values.toSet().length==values.length;
    if(filters is! List||stickers is! List||!valid(filters,approvedFilters)||
      !valid(stickers,approvedStickers)||!filters.contains('natural'))return restricted;
    return OrbitCameraToolCatalog._(
      List<String>.unmodifiable(approvedFilters.where(filters.contains)),
      List<String>.unmodifiable(approvedStickers.where(stickers.contains)));
  }
  bool allowsFilter(String name)=>filters.contains(name);
  bool allowsSticker(String emoji)=>stickers.contains(emoji);
}
