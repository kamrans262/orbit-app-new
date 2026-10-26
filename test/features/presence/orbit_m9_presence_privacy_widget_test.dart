import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/theme/app_theme.dart';
import 'package:orbit_ui/features/presence/data/orbit_presence_repository.dart';
import 'package:orbit_ui/features/presence/presentation/orbit_circle_presence_settings_screen.dart';

void main() {
  const circle='01234567-89ab-cdef-0123-456789abcdef';

  testWidgets('Presence opt-in uses existing popup and does not bypass Ghost Mode', (tester) async {
    final updates=<Map<String,Object?>>[];
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (path=='/me/presence/settings') return {'data':{
        'global':{'ghost_mode_enabled':true,'presence_visibility':'Nobody'},
        'circles':[],
      }};
      if (method=='PUT') {
        updates.add(Map<String,Object?>.from(body ?? {}));
        return {'data':{'circle_id':circle,'requested':true}};
      }
      return {'data':{}};
    });

    await tester.pumpWidget(MaterialApp(
      theme:AppTheme.light,
      home:OrbitCirclePresenceSettingsScreen(
        circleId:circle,circleName:'Family',repository:repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ghost Mode'),findsOneWidget);
    expect(updates,isEmpty);

    await tester.tap(find.text('Share my online status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Presence setting'));
    await tester.pumpAndSettle();
    expect(find.text('Share your online status?'),findsOneWidget);
    expect(updates,isEmpty);

    await tester.tap(find.text('Allow sharing'));
    await tester.pumpAndSettle();
    expect(updates.length,1);
    expect(updates.single['enabled'],true);
    expect(updates.single['duration'],'until_expiry');
    expect(updates.single['expires_at'],isNotNull);
    expect(find.textContaining('Ghost Mode'),findsOneWidget);
  });

  testWidgets('No Presence consent is written on load or back navigation', (tester) async {
    var writes=0;
    final repo=OrbitPresenceRepository(request:(method,path,{body}) async {
      if (method!='GET') writes++;
      return {'data':{
        'global':{'ghost_mode_enabled':false,'presence_visibility':'My Circle'},
        'circles':[],
      }};
    });
    await tester.pumpWidget(MaterialApp(
      theme:AppTheme.light,
      home:OrbitCirclePresenceSettingsScreen(
        circleId:circle,circleName:'Friends',repository:repo)));
    await tester.pumpAndSettle();
    expect(writes,0);
    expect(find.text('Share my online status'),findsOneWidget);
  });
}
