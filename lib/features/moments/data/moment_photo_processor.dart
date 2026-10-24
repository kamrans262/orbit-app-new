import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

/// M7 image editing happens locally, before M6 ciphertext staging. Decoding
/// and JPEG re-encoding discard source EXIF/GPS and other metadata.
enum MomentFilter {
  natural('Natural'), warm('Warm'), cool('Cool'), portrait('Portrait'),
  film('Film'), night('Night'), soft('Soft'), vibrant('Vibrant'),
  blackAndWhite('Black & White');
  const MomentFilter(this.label);
  final String label;
}

class MomentDrawStroke {
  const MomentDrawStroke(this.points);
  /// Normalized points so preview and exported pixels use identical strokes.
  final List<Offset> points;
}

class MomentPhotoEdit {
  const MomentPhotoEdit({
    this.filter=MomentFilter.natural,
    this.text='',
    this.strokes=const [],
  });
  final MomentFilter filter;
  final String text;
  final List<MomentDrawStroke> strokes;
}

abstract final class MomentPhotoProcessor {
  static Uint8List render(Uint8List source,MomentPhotoEdit edit){
    if(source.isEmpty || source.length>26*1024*1024){
      throw const FormatException('Photo exceeds the secure editor size limit.');
    }
    final decoded=img.decodeImage(source);
    if(decoded==null)throw const FormatException('Unsupported photo format.');
    var image=img.bakeOrientation(decoded);
    final edge=image.width>image.height?image.width:image.height;
    if(edge>1440){
      image=img.copyResize(image,
        width:image.width*1440~/edge,
        height:image.height*1440~/edge,
        interpolation:img.Interpolation.linear);
    }
    final w=image.width, h=image.height;
    for(var y=0;y<h;y++){
      for(var x=0;x<w;x++){
        final p=image.getPixel(x,y);
        final r=p.r.toInt(),g=p.g.toInt(),b=p.b.toInt();
        final l=(r*0.299+g*0.587+b*0.114).round();
        int rr=r,gg=g,bb=b;
        switch(edit.filter){
          case MomentFilter.natural:break;
          case MomentFilter.warm:rr=r+15;gg=g+4;bb=b-13;break;
          case MomentFilter.cool:rr=r-10;gg=g+1;bb=b+16;break;
          case MomentFilter.portrait:
            rr=(r*.95+l*.05+9).round();
            gg=(g*.95+l*.05+7).round();
            bb=(b*.95+l*.05+5).round();
          case MomentFilter.film:
            rr=(r*.86+l*.14+13).round();
            gg=(g*.83+l*.17+7).round();
            bb=(b*.82+l*.18+2).round();
          case MomentFilter.night:rr=(r*.68).round();gg=(g*.76).round();bb=(b*.95+9).round();break;
          case MomentFilter.soft:rr=(r*.78+l*.22+6).round();gg=(g*.78+l*.22+6).round();bb=(b*.78+l*.22+6).round();break;
          case MomentFilter.vibrant:rr=(l+(r-l)*1.30).round();gg=(l+(g-l)*1.30).round();bb=(l+(b-l)*1.30).round();break;
          case MomentFilter.blackAndWhite:rr=l;gg=l;bb=l;break;
        }
        image.setPixelRgb(x,y,rr.clamp(0,255).toInt(),
          gg.clamp(0,255).toInt(),bb.clamp(0,255).toInt());
      }
    }
    for(final stroke in edit.strokes){
      if(stroke.points.length<2)continue;
      for(var i=1;i<stroke.points.length;i++){
        final a=stroke.points[i-1],b=stroke.points[i];
        img.drawLine(image,
          x1:(a.dx.clamp(0.0,1.0)*(w-1)).round(),
          y1:(a.dy.clamp(0.0,1.0)*(h-1)).round(),
          x2:(b.dx.clamp(0.0,1.0)*(w-1)).round(),
          y2:(b.dy.clamp(0.0,1.0)*(h-1)).round(),
          color:img.ColorRgb8(255,255,255),thickness:3);
      }
    }
    final text=edit.text.trim();
    if(text.isNotEmpty){
      if(text.runes.length>80)throw const FormatException('Overlay text too long.');
      img.drawString(image,text,font:img.arial24,
        x:(w*.08).round(),y:(h*.75).round(),
        color:img.ColorRgb8(255,255,255));
    }
    // Encoded output has only rendered pixels: no GPS/EXIF or metadata.
    return Uint8List.fromList(img.encodeJpg(image,quality:86));
  }
}
