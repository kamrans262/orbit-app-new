import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/profile_models.dart';
import '../widgets/profile_media_image.dart';

class ProfileMomentDetailScreen extends StatelessWidget {
  const ProfileMomentDetailScreen({required this.moment, super.key});

  final ProfileMomentData moment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: SingleChildScrollView(
                child: ProfileMediaImage(
                  assetPath: moment.imagePath,
                  imageUrl: moment.imageUrl,
                  width: MediaQuery.sizeOf(context).width,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              child: Material(
                color: const Color(0x66000000),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (moment.likeCount != null)
              Positioned(
                left: 20,
                bottom: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.favorite_rounded,
                          size: 17,
                          color: Color(0xFFFF4757),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${moment.likeCount}',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
