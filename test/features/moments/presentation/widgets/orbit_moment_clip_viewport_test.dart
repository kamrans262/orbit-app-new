import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/orbit_private_moment_player.dart';

void main(){
  for(final viewport in const [Size(320,440),Size(320,200),Size(260,100),Size(600,300)]){
    for(final ratio in [9/16,16/9,1.0]){
      testWidgets('clip fits ${viewport.width}x${viewport.height} ratio $ratio',(tester)async{
        const mediaKey=ValueKey('video-frame');
        const controlsKey=ValueKey('video-controls');
        const viewportKey=ValueKey('viewport');
        await tester.pumpWidget(MaterialApp(
          home:Scaffold(
            body:Center(
              child:SizedBox(
                key:viewportKey,width:viewport.width,height:viewport.height,
                child:OrbitMomentClipViewport(
                  aspectRatio:ratio,
                  media:const ColoredBox(key:mediaKey,color:Colors.black),
                  controls:Row(key:controlsKey,mainAxisSize:MainAxisSize.min,children:[
                    IconButton(onPressed:(){},icon:const Icon(Icons.play_circle_fill,size:54)),
                    const SizedBox(width:12),
                    IconButton(onPressed:(){},icon:const Icon(Icons.volume_up_outlined,size:28)),
                  ]),
                ),
              ),
            ),
          ),
        ));
        final frame=tester.getRect(find.byKey(mediaKey));
        final controls=tester.getRect(find.byKey(controlsKey));
        final bounds=tester.getRect(find.byKey(viewportKey));
        expect(frame.width/frame.height,closeTo(ratio,0.001));
        expect(frame.width,lessThanOrEqualTo(bounds.width+0.01));
        expect(frame.top,greaterThanOrEqualTo(bounds.top-0.01));
        expect(frame.bottom,lessThanOrEqualTo(controls.top+0.01));
        expect(controls.bottom,lessThanOrEqualTo(bounds.bottom+0.01));
        expect(tester.takeException(),isNull);
      });
    }
  }
  testWidgets('voice clip remains bounded when comments shrink the viewer',(tester)async{
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:Center(child:SizedBox(width:260,height:100,
        child:OrbitMomentClipViewport(
          media:const Icon(Icons.mic_none_outlined,size:64),
          controls:IconButton(onPressed:(){},icon:const Icon(Icons.play_circle_fill,size:54)),
        ),
      ))),
    ));
    expect(tester.takeException(),isNull);
  });
}
