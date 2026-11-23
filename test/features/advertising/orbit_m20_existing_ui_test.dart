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
}
