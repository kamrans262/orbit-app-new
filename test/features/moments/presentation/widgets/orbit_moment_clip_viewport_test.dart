import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/orbit_private_moment_player.dart';

void main(){
  testWidgets('video taps toggle playback and a separate small top-right sound control toggles mute',(tester)async{
    var playing=true,muted=false,toggles=0,mutes=0;
    const mediaKey=ValueKey('overlay-video');
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:SizedBox(width:320,height:320,child:StatefulBuilder(builder:(context,update)=>
        OrbitMomentVideoFrame(aspectRatio:16/9,playing:playing,muted:muted,
          media:const ColoredBox(key:mediaKey,color:Colors.black),
          onToggle:()=>update((){playing=!playing;toggles++;}),
          onMute:()=>update((){muted=!muted;mutes++;})),
      )),
    ))));
    final frame=tester.getRect(find.byKey(mediaKey));
    final sound=find.byTooltip('Mute encrypted video');
    final soundRect=tester.getRect(sound);
    expect(soundRect.width,32);
    expect(soundRect.top-frame.top,8);
    expect(frame.right-soundRect.right,8);
    await tester.tapAt(frame.center);await tester.pumpAndSettle();
    expect(toggles,1);
    expect(playing,false);
    expect(find.byIcon(Icons.play_circle_fill),findsOneWidget);
    await tester.tap(sound);await tester.pumpAndSettle();
    expect(mutes,1);expect(toggles,1);
    expect(find.byTooltip('Unmute encrypted video'),findsOneWidget);
    await tester.tapAt(frame.center);await tester.pump();
    expect(playing,true);expect(toggles,2);
    await tester.pump(const Duration(seconds:1));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });

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
        // The frame starts at the top, and controls follow it directly even
        // when a landscape clip does not consume the entire viewport.
        expect(frame.top,closeTo(bounds.top,0.01));
        expect(controls.top-frame.bottom,lessThanOrEqualTo(24));
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
