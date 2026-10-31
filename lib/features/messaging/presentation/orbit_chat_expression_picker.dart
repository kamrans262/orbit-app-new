import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../data/orbit_messaging_stickers.dart';

/// No separate navigation or unfamiliar colors. Both chat screens reuse
/// the already-approved full-width Orbit Circle sheet.
Future<String?> showOrbitChatExpressionPicker(BuildContext context) =>
  showOrbitCircleSheet<String>(
    context:context,title:'Emoji & Stickers',
    builder:(sheet)=>_OrbitExpressionChoices(
      onChosen:(value)=>Navigator.of(sheet).pop(value)),
  );

class _OrbitExpressionChoices extends StatefulWidget {
  const _OrbitExpressionChoices({required this.onChosen});
  final ValueChanged<String> onChosen;
  @override
  State<_OrbitExpressionChoices> createState()=>_OrbitExpressionChoicesState();
}

class _OrbitExpressionChoicesState extends State<_OrbitExpressionChoices> {
  bool _stickers=true;
  static const emoji=<String>[
    '😀','😁','😂','🥰','😍','😘','😊','😎','🤩','🥳',
    '😮','😢','😭','😡','🤔','🙌','👏','👍','👎','🙏',
    '❤️','💕','💜','💯','🎉','🎂','🔥','✨','🌟','🌈',
    '☕','🌸','🌻','🐱','💪','🤝','👋','💌','🫶','😴',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[
        Expanded(child:_choice('Stickers',_stickers,
          ()=>setState(()=>_stickers=true))),
        const SizedBox(width:10),
        Expanded(child:_choice('Emoji',!_stickers,
          ()=>setState(()=>_stickers=false))),
      ]),
      const SizedBox(height:16),
      GridView.builder(
        key:Key(_stickers?'orbit_sticker_grid':'orbit_emoji_grid'),
        shrinkWrap:true,
        physics:const NeverScrollableScrollPhysics(),
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:_stickers?4:6,
          mainAxisSpacing:10,crossAxisSpacing:10,
          childAspectRatio:_stickers?0.89:1),
        itemCount:_stickers?OrbitChatSticker.ids.length:emoji.length,
        itemBuilder:(context,index){
          if(!_stickers){
            final glyph=emoji[index];
            return Semantics(label:'Emoji $glyph',button:true,
              child:InkWell(
                key:Key('orbit_emoji_$index'),
                onTap:()=>widget.onChosen(glyph),
                borderRadius:BorderRadius.circular(14),
                child:Center(child:Text(glyph,
                  style:const TextStyle(fontSize:28,height:1)))));
          }
          final id=OrbitChatSticker.ids.elementAt(index);
          return Semantics(label:'Sticker ${OrbitStickerArtwork.label(id)}',
            button:true,child:InkWell(
              key:Key('orbit_sticker_$id'),
              borderRadius:BorderRadius.circular(16),
              onTap:()=>widget.onChosen(OrbitChatSticker(id).encode()),
              child:Column(children:[
                Expanded(child:OrbitStickerArtwork(id:id,compact:true)),
                const SizedBox(height:3),
                Text(OrbitStickerArtwork.label(id),
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontFamily:AppTypography.fontFamily,
                    fontSize:10,color:AppColors.textPrimary)),
              ])));
        }),
    ]);
  }

  Widget _choice(String label,bool active,VoidCallback onTap)=>
    Material(color:Colors.transparent,
      child:InkWell(
        onTap:onTap,borderRadius:BorderRadius.circular(22),
        child:Container(
          padding:const EdgeInsets.symmetric(vertical:11),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(22),
            color:active?AppColors.primaryEnd:AppColors.background),
          child:Center(child:Text(label,style:TextStyle(
            fontFamily:AppTypography.fontFamily,fontSize:13,
            fontWeight:FontWeight.w600,
            color:active?AppColors.white:AppColors.textPrimary))),
      ));
}

/// Original vector-based sticker artwork, not an emoji passed off as a
/// sticker. Preserves Orbit's existing pink/purple gradient and typography.
class OrbitStickerArtwork extends StatelessWidget {
  const OrbitStickerArtwork({
    required this.id,this.compact=false,super.key,
  });
  final String id;
  final bool compact;

  static IconData iconFor(String id)=>switch(id){
    'orbit-heart'=>Icons.favorite_rounded,
    'orbit-cheer'=>Icons.celebration_rounded,
    'orbit-star'=>Icons.auto_awesome_rounded,
    'orbit-hello'=>Icons.waving_hand_rounded,
    'orbit-hug'=>Icons.volunteer_activism_rounded,
    'orbit-coffee'=>Icons.local_cafe_rounded,
    'orbit-party'=>Icons.cake_rounded,
    'orbit-smile'=>Icons.sentiment_very_satisfied_rounded,
    _=>Icons.help_outline_rounded,
  };
  static String label(String id)=>switch(id){
    'orbit-heart'=>'Love',
    'orbit-cheer'=>'Celebrate',
    'orbit-star'=>'Amazing',
    'orbit-hello'=>'Hello',
    'orbit-hug'=>'Hugs',
    'orbit-coffee'=>'Coffee',
    'orbit-party'=>'Party',
    'orbit-smile'=>'Smile',
    _=>'Sticker',
  };

  @override
  Widget build(BuildContext context) {
    if(!OrbitChatSticker.ids.contains(id)){
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      key:Key('orbit_sticker_art_$id'),
      decoration:BoxDecoration(
        gradient:AppColors.primaryGradient,
        borderRadius:BorderRadius.circular(compact?17:24)),
      child:SizedBox.square(
        dimension:compact?64:108,
        child:Center(child:Icon(iconFor(id),
          color:AppColors.white,size:compact?37:65)),
      ),
    );
  }
}
