import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/home_models.dart';

/// Existing Orbit color tokens only. Does not imply presence or live location.
class HomeCircleSummaryTile extends StatelessWidget {
  const HomeCircleSummaryTile({required this.data,required this.onTap,super.key});
  final HomeCircleSummaryData data;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context)=>SizedBox(
    width:112,
    child:Material(
      color:const Color(0xFFF2EAFE),
      borderRadius:BorderRadius.circular(16),
      child:InkWell(
        onTap:onTap,borderRadius:BorderRadius.circular(16),
        child:Padding(
          padding:const EdgeInsets.all(10),
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:<Widget>[
              const Icon(Icons.groups_outlined,size:24,color:AppColors.primaryEnd),
              const Spacer(),
              Text(data.name,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontFamily:AppTypography.fontFamily,
                  fontSize:12,fontWeight:FontWeight.w600,color:AppColors.primaryEnd)),
              Text(data.memberCount==1 ? '1 member' : data.memberCount.toString()+' members',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontFamily:AppTypography.fontFamily,
                  fontSize:10,color:AppColors.textMuted)),
            ],
          ),
        ),
      ),
    ),
  );
}
