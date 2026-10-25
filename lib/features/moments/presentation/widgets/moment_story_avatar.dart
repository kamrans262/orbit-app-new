import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/moments_models.dart';
import 'moment_media_image.dart';

class MomentStoryAvatar extends StatelessWidget {
  const MomentStoryAvatar({required this.data, required this.onTap, super.key});

  static const double avatarSize = 54;

  final MomentStoryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(clipBehavior:Clip.none,children:[
            Container(
              width: avatarSize,
              height: avatarSize,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF7C3AED), width: 2),
              ),
              child: data.isAddStory
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 24,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    )
                  : ClipOval(
                      child: SizedBox.square(
                        dimension: 50,
                        child: MomentMediaImage(
                          path: data.imagePath,
                          bytes:data.imageBytes,
                          fit: BoxFit.cover,
                          fallback: const ColoredBox(
                            color: Color(0xFFF0ECF8),
                            child: Center(
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 24,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            if(data.isCircle && !data.isAddStory)Positioned(
              left:0,top:0,
              child:Semantics(label:'Circle Moment',child:Container(
                width:17,height:17,
                decoration:BoxDecoration(color:AppColors.background,
                  shape:BoxShape.circle,border:Border.all(color:AppColors.white)),
                child:const Icon(Icons.groups_outlined,size:12,
                  color:AppColors.primaryEnd),
              )),
            ),
            if(data.isUnseen&&!data.isAddStory)Positioned(
              right:0,bottom:0,
              child:Semantics(label:'Unseen private Moment',child:Container(
                width:12,height:12,
                decoration:BoxDecoration(
                  color:const Color(0xFF3B82F6),shape:BoxShape.circle,
                  border:Border.all(color:AppColors.white,width:2)),
              )),
            ),
            ]),
            const SizedBox(height: 5),
            Text(
              data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            if(data.ageLabel!=null)Text(
              data.ageLabel!,
              maxLines:1,overflow:TextOverflow.ellipsis,
              textAlign:TextAlign.center,
              style:const TextStyle(
                fontFamily:AppTypography.fontFamily,fontSize:10,
                height:1.15,color:AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
