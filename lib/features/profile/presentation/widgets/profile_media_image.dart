import 'package:flutter/material.dart';

class ProfileMediaImage extends StatelessWidget {
  const ProfileMediaImage({
    this.assetPath,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackAspectRatio = 0.82,
    super.key,
  });

  final String? assetPath;
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double fallbackAspectRatio;

  @override
  Widget build(BuildContext context) {
    final localPath = assetPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      return Image.asset(
        localPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    final remoteUrl = imageUrl?.trim();
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return _fallback(showProgress: true);
        },
      );
    }

    return _fallback();
  }

  Widget _fallback({bool showProgress = false}) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
      child: Center(
        child: showProgress
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_outlined,
                size: 28,
                color: Color(0xFF94A3B8),
              ),
      ),
    );

    if (height != null) {
      return SizedBox(width: width, height: height, child: fallback);
    }

    return AspectRatio(
      aspectRatio: fallbackAspectRatio,
      child: SizedBox(width: width, child: fallback),
    );
  }
}
