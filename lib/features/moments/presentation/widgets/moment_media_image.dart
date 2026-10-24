import 'package:flutter/material.dart';
import 'dart:typed_data';

class MomentMediaImage extends StatelessWidget {
  const MomentMediaImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallback,
    this.bytes,
    super.key,
  });

  final String? path;
  final Uint8List? bytes;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final resolvedPath = path?.trim();
    final fallbackWidget =
        fallback ??
        const ColoredBox(
          color: Color(0xFFF0ECF8),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 34,
              color: Color(0xFF8A85A8),
            ),
          ),
        );

    if(bytes!=null && bytes!.isNotEmpty){
      return Image.memory(bytes!,fit:fit,alignment:alignment,
        filterQuality:FilterQuality.high,
        errorBuilder:(_,error,stack)=>fallbackWidget);
    }
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return fallbackWidget;
    }

    return Image.asset(
      resolvedPath,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => fallbackWidget,
    );
  }
}
