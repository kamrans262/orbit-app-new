import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/widgets/app_circular_icon_button.dart';
import 'package:orbit_ui/core/widgets/app_screen_header.dart';
import 'package:orbit_ui/features/friends/data/orbit_social_repository.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_discover_friends_screen.dart';
import 'package:orbit_ui/features/friends/presentation/screens/orbit_discovery_preferences_screen.dart';

class _FakeDiscoveryRepository extends OrbitSocialRepository {
  final Map<String, dynamic> preferences = <String, dynamic>{
    'discoverable': true,
    'discoverable_by_name': true,
    'discoverable_by_contacts': false,
    'allow_friend_requests': true,
  };

  @override
  Future<Map<String, dynamic>> discoverySettings() async =>
      Map<String, dynamic>.from(preferences);

  @override
  Future<Map<String, dynamic>> updateDiscovery(
      Map<String, Object?> values) async {
    preferences.addAll(values);
    return Map<String, dynamic>.from(preferences);
  }
}

void main() {
  testWidgets('Friend Discovery uses existing prominent Orbit header style',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeDiscoveryRepository();

    await tester.pumpWidget(MaterialApp(
      home: OrbitDiscoverFriendsScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Friend discovery settings'));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitDiscoveryPreferencesScreen), findsOneWidget);

    final back = tester.widget<AppCircularIconButton>(
        find.byKey(OrbitDiscoveryHeaderKeys.back));
    expect(back.size, 40);
    expect(back.iconSize, 24);

    final title = tester.widget<Text>(
        find.byKey(OrbitDiscoveryHeaderKeys.title));
    expect(title.data, 'Friend Discovery');
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(find.byType(AppScreenHeader), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(OrbitDiscoveryHeaderKeys.back));
    await tester.pumpAndSettle();
    expect(find.byType(OrbitDiscoverFriendsScreen), findsOneWidget);
    expect(find.byType(OrbitDiscoveryPreferencesScreen), findsNothing);
  });

  testWidgets('Prominent header is opt-in, preserving legacy detail headers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SafeArea(child: AppScreenHeader(
        title: 'Default detail title',
        backButtonKey: const Key('default_header_back'),
        titleKey: const Key('default_header_title'),
        onBack: () {},
      ))),
    ));
    final back = tester.widget<AppCircularIconButton>(
        find.byKey(const Key('default_header_back')));
    final title = tester.widget<Text>(
        find.byKey(const Key('default_header_title')));
    expect(back.size, 30);
    expect(title.style?.fontSize, 16);
    expect(tester.takeException(), isNull);
  });
}
