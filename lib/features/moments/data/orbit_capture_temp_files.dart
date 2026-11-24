import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Only this feature's app-owned transient files are swept. Never follow
/// symlinks or recursively remove arbitrary picker/plug-in directories.
class OrbitCaptureTempFiles {
  OrbitCaptureTempFiles({Future<Directory> Function()? temporaryDirectory})
    : _base=temporaryDirectory??getTemporaryDirectory;
  final Future<Directory> Function() _base;
  static const folder='orbit-m23-capture-scratch';
  static final _known=RegExp(r'^[a-fA-F0-9-]{36}\.(mp4|m4a)$');
  static final _legacy=RegExp(r'^orbit-m7-(voice-[0-9]+\.m4a|recovered-[a-fA-F0-9-]{36}\.(mp4|m4a))$');
  Future<Directory> _root() async{
    final base=await _base();
    final root=Directory(base.path+'/'+folder);
    final type=await FileSystemEntity.type(root.path,followLinks:false);
    if(type!=FileSystemEntityType.notFound&&type!=FileSystemEntityType.directory){
      throw const FileSystemException('Unsafe capture scratch directory.');
    }
    await root.create(recursive:true);return root;
  }
  Future<File> allocate(String extension) async{
    if(extension!='mp4'&&extension!='m4a')throw const FormatException('Invalid clip type.');
    final root=await _root();
    return File(root.path+'/'+const Uuid().v4()+'.'+extension);
  }
  Future<File> copyClip(File source,{required String extension,required int maxBytes}) async{
    final output=await allocate(extension);
    final sink=output.openWrite();
    var written=0;
    try{
      await for(final chunk in source.openRead()){
        written+=chunk.length;
        if(written>maxBytes)throw const FormatException('Clip too large.');
        sink.add(chunk);
        // Backpressure bounds pending writes during large imports.
        await sink.flush();
      }
      if(written<1)throw const FormatException('Empty clip.');
      await sink.close();
      return output;
    }catch(_){
      try{await sink.close();}catch(_){}
      if(await output.exists())await output.delete();
      rethrow;
    }
  }
  Future<bool> isAppCacheFile(File file) async{
    final root=await (await _base()).resolveSymbolicLinks();
    if(await FileSystemEntity.type(file.path,followLinks:false)!=FileSystemEntityType.file)return false;
    final path=await file.resolveSymbolicLinks();
    return path.startsWith(root+Platform.pathSeparator);
  }
  Future<void> deleteCacheFile(File file) async{
    if(await isAppCacheFile(file))await file.delete();
  }
  /// Called once at fresh foreground startup, before any camera can open.
  /// Only delete files this app explicitly named, not other cache contents.
  Future<void> sweepInterrupted() async{
    final root=await _root();
    await for(final entity in root.list(followLinks:false)){
      if(entity is File&&_known.hasMatch(entity.uri.pathSegments.last))await entity.delete();
    }
    final base=await _base();
    await for(final entity in base.list(followLinks:false)){
      if(entity is File&&_legacy.hasMatch(entity.uri.pathSegments.last))await entity.delete();
    }
  }
}
