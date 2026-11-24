import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/home/domain/models/home_models.dart';
import 'package:orbit_ui/features/home/presentation/widgets/promo_banner_card.dart';
import 'package:orbit_ui/features/advertising/presentation/orbit_ad_visibility.dart';

void main(){
  testWidgets('M20 uses the exact existing Sponsored banner and its keys',
      (tester) async {
    var tapped=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:PromoBannerCard(
      data:PromoBannerData(
        id:'approved',
        backgroundImagePath:'',logoImagePath:'',
        title:'A verified sponsored card',
        subtitle:'Existing Orbit text hierarchy',
        imageBytes:Uint8List.fromList([137,80,78,71,13,10,26,10]),
      ),
      onTap:()=>tapped++,
    ))));
    expect(find.byKey(PromoBannerKeys.title),findsOneWidget);
    expect(find.text('Sponsored'),findsOneWidget);
    expect(find.text('A verified sponsored card'),findsOneWidget);
    await tester.tap(find.byType(PromoBannerCard));
    expect(tapped,1);
  });

  testWidgets('M20 invisible wrapper preserves promo layout and no tap',
      (tester) async {
    var measured=0,tapped=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      OrbitAdVisibility(
        minimumVisibleMs:5000,
        onVisible:(_)=>measured++,
        child:PromoBannerCard(
          data:const PromoBannerData(
            id:'approved',backgroundImagePath:'',logoImagePath:'',
            title:'Same approved UI',subtitle:'No added dialogs'),
          onTap:()=>tapped++,
        ),
      ),
    )));
    expect(find.byType(PromoBannerCard),findsOneWidget);
    expect(find.text('Sponsored'),findsOneWidget);
    expect(measured,0);
    await tester.tap(find.byType(PromoBannerCard));
    expect(tapped,1);
    expect(measured,0);
  });
  testWidgets('Visible creative is sampled, but clipped and covered creative is not',
      (tester) async {
    var measured=0;
    Widget creative(String key)=>OrbitAdVisibility(
      key:ValueKey(key),minimumVisibleMs:0,onVisible:(_)=>measured++,
      child:const SizedBox(width:200,height:100,
        child:ColoredBox(color:Colors.blue)));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:creative('visible')))));
    await tester.pump(const Duration(milliseconds:300));
    expect(measured,1);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:SizedBox(width:200,height:20,child:ClipRect(
        child:OverflowBox(minHeight:100,maxHeight:100,
          child:creative('clipped'))))))));
    await tester.pump(const Duration(milliseconds:600));
    expect(measured,1);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:Stack(children:[creative('covered'),const Positioned.fill(
        child:ColoredBox(color:Colors.black))])))));
    await tester.pump(const Duration(milliseconds:600));
    expect(measured,1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
