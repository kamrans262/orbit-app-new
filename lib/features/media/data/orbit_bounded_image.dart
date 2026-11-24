import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Inspect header before decoding pixels; only supported still images.
abstract final class OrbitBoundedImage {
  static img.Image decode(Uint8List bytes){
    if(bytes.isEmpty||bytes.length>25*1024*1024)throw const FormatException('Invalid photo size.');
    final decoder=img.findDecoderForData(bytes);
    if(decoder==null)throw const FormatException('Unsupported still image.');
    final info=decoder.startDecode(bytes);
    if(info==null||info.width<1||info.height<1||info.width>16000||
        info.height>16000||info.width*info.height>40000000||
        decoder.numFrames()!=1)throw const FormatException('Unsupported or oversized still image.');
    final decoded=decoder.decodeFrame(0);
    if(decoded==null||decoded.width*decoded.height>40000000){
      throw const FormatException('Image could not be decoded.');
    }
    return decoded;
  }
}
