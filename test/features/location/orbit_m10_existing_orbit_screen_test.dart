import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';

void main(){
  testWidgets('live Orbits reuses sheet without demo identity or fake LIVE badge',(tester)async{
    await tester.pumpWidget(MaterialApp(home:OrbitScreen.live(
      onTabSelected:(_){},onAddPressed:(){})));
    await tester.pump();
    expect(find.byKey(OrbitKeys.sheet),findsOneWidget);
    expect(find.text('LIVE'),findsNothing);
    expect(find.text('Suzie'),findsNothing);
    expect(find.text('Location is not enabled for this build.'),findsOneWidget);
  });
}
