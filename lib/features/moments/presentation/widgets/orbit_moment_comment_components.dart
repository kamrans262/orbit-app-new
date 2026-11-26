import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moments_models.dart';
import 'moment_profile_avatar.dart';

/// Shared, approved Moments comments presentation. Both surfaces retain
/// their own authorized scope, callbacks and lifecycle; no data access here.
class OrbitMomentCommentsHeader extends StatelessWidget {
  const OrbitMomentCommentsHeader({required this.onClose,super.key});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Divider(height:1,color:AppColors.primaryEnd.withValues(alpha:0.14)),
    Row(children:[
      Expanded(child:Text('Comments',style:AppTypography.body.copyWith(
        fontWeight:FontWeight.w600,color:AppColors.primaryEnd))),
      IconButton(tooltip:'Close comments',onPressed:onClose,
        icon:const Icon(Icons.close_rounded,color:AppColors.primaryEnd)),
    ]),
  ]);
}

class OrbitMomentCommentRow extends StatelessWidget {
  const OrbitMomentCommentRow({required this.authorId,required this.authorName,
    required this.body,required this.isReply,required this.onReply,
    this.avatarBytes,this.onDelete,this.onReport,super.key});
  final String authorId,authorName,body;
  final bool isReply;
  final Uint8List? avatarBytes;
  final VoidCallback onReply;
  final VoidCallback? onDelete,onReport;

  @override
  Widget build(BuildContext context)=>Padding(
    padding:EdgeInsets.fromLTRB(isReply?14:0,6,0,6),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      MomentProfileAvatar(author:MomentAuthorData(id:authorId,
        name:authorName,imageBytes:avatarBytes),
        size:34,borderColor:AppColors.primaryStart.withValues(alpha:0.25),borderWidth:1),
      const SizedBox(width:8),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
          decoration:BoxDecoration(
            color:AppColors.white,borderRadius:BorderRadius.circular(14),
            border:Border.all(color:AppColors.primaryEnd.withValues(alpha:0.10))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(authorName,style:AppTypography.body.copyWith(
              fontWeight:FontWeight.w600,color:AppColors.primaryEnd)),
            const SizedBox(height:3),
            Text(body,style:AppTypography.body.copyWith(color:AppColors.textPrimary)),
          ])),
        Padding(padding:const EdgeInsets.only(left:8,top:4),
          child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:12,children:[
            InkWell(onTap:onReply,
              child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:4),
                child:Text('Reply',style:AppTypography.bodyMuted.copyWith(
                  color:AppColors.primaryEnd,fontWeight:FontWeight.w600)))),
            if(onDelete!=null)Tooltip(message:'Delete comment',child:InkWell(onTap:onDelete,
              child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:4),
                child:Text('Delete',style:AppTypography.bodyMuted)))),
            if(onReport!=null)Tooltip(message:'Report this private comment',child:InkWell(onTap:onReport,
              child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:4),
                child:Text('Report',style:AppTypography.bodyMuted)))),
          ])),
      ])),
    ]));
}

class OrbitMomentCommentComposer extends StatelessWidget {
  const OrbitMomentCommentComposer({required this.controller,required this.enabled,
    required this.onSend,super.key});
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
    Expanded(child:TextField(controller:controller,maxLength:280,maxLines:1,
      style:AppTypography.body.copyWith(fontSize:12,height:1.3),
      enabled:enabled,decoration:InputDecoration(hintText:'Write a comment',counterText:'',
        filled:true,fillColor:AppColors.white,isDense:true,
        hintStyle:AppTypography.bodyMuted.copyWith(fontSize:12,height:1.3),
        contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(24),
          borderSide:BorderSide(color:AppColors.primaryEnd.withValues(alpha:0.16))),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(24),
          borderSide:const BorderSide(color:AppColors.primaryEnd))))),
    const SizedBox(width:8),
    Semantics(button:true,label:'Send comment',child:Material(color:Colors.transparent,
      child:Ink(decoration:const BoxDecoration(shape:BoxShape.circle,gradient:AppColors.primaryGradient),
        child:InkWell(customBorder:const CircleBorder(),onTap:enabled?onSend:null,
          child:const SizedBox.square(dimension:36,child:Center(
            child:Icon(Icons.send_rounded,color:AppColors.white,size:18))))))),
  ]);
}
