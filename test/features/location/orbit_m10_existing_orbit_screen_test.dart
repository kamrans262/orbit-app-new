import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:orbit_ui/features/location/presentation/orbit_location_live_map.dart';
import 'package:orbit_ui/features/orbit/presentation/widgets/orbit_map_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/orbit/presentation/screens/orbit_screen.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown((){
    messenger.setMockMethodCallHandler(OrbitMapProvider.channel,null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
  });

  test('native map configuration is checked independently of the location API',()async{
    messenger.setMockMethodCallHandler(OrbitMapProvider.channel,(call)async{
      expect(call.method,'configured');
      expect(call.arguments,isNull);
      return true;
    });
    expect(await OrbitMapProvider.configured(),isTrue);
    messenger.setMockMethodCallHandler(OrbitMapProvider.channel,(_)async=>false);
    expect(await OrbitMapProvider.configured(),isFalse);
  });

  testWidgets('empty live Orbits still mounts the actual Google map with no member pins',(tester)async{
    messenger.setMockMethodCallHandler(OrbitMapProvider.channel,(_)async=>true);
    // Native view allocation is a platform responsibility; the test checks
    // the actual GoogleMap widget and its privacy-safe empty marker contract.
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call)async{
      if(call.method=='create')return 1;
      if(call.method=='resize')return {'width':400.0,'height':600.0};
      return null;
    });
    await tester.pumpWidget(MaterialApp(home:OrbitScreen.live()));
    for(var i=0;i<5;i++)await tester.pump();
    final map=find.byType(GoogleMap);
    expect(map,findsOneWidget);
    final widget=tester.widget<GoogleMap>(map);
    expect(widget.markers,isEmpty);
    expect(widget.myLocationEnabled,isFalse);
    expect(find.byType(OrbitMapMarker),findsNothing);
    expect(find.text('No people in this Orbit yet.'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('missing SDK configuration is reported rather than presenting a blank map as ready',(tester)async{
    messenger.setMockMethodCallHandler(OrbitMapProvider.channel,(_)async=>false);
    await tester.pumpWidget(MaterialApp(home:OrbitScreen.live()));
    for(var i=0;i<5;i++)await tester.pump();
    expect(find.byType(GoogleMap),findsNothing);
    expect(find.text('Map provider configuration is required.'),findsOneWidget);
    expect(find.byType(OrbitMapMarker),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('live Orbits reuses sheet without demo identity or fake LIVE badge',(tester)async{
    await tester.pumpWidget(MaterialApp(home:OrbitScreen.live(
      onTabSelected:(_){},onAddPressed:(){})));
    await tester.pump();
    expect(find.byKey(OrbitKeys.sheet),findsOneWidget);
    expect(find.text('LIVE'),findsNothing);
    expect(find.text('Suzie'),findsNothing);
    expect(find.text('Location is not enabled for this build.'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
