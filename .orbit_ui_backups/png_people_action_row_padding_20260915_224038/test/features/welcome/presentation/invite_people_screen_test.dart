import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orbit_ui/app/theme/app_colors.dart';
import 'package:orbit_ui/app/theme/app_typography.dart';
import 'package:orbit_ui/core/widgets/app_action_row.dart';
import 'package:orbit_ui/features/welcome/domain/models/nearby_person.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/invite_people_screen.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/invite_option_tile.dart';
import 'package:orbit_ui/features/welcome/presentation/widgets/nearby_person_tile.dart';

void main() {
  Widget buildScreen({ValueChanged<NearbyPerson>? onAdd}) {
    return MaterialApp(
      theme: ThemeData(fontFamily: AppTypography.fontFamily),
      home: InvitePeopleScreen(
        onInviteByContacts: () {},
        onInviteByQrCode: () {},
        onInviteByLink: () {},
        onInviteByUsername: () {},
        onAddPerson: onAdd ?? (_) {},
      ),
    );
  }

  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'Invite People typography and shared invite containers match spec',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final heading = tester.widget<Text>(find.byKey(InvitePeopleKeys.heading));
      final body = tester.widget<Text>(find.byKey(InvitePeopleKeys.body));
      final nearby = tester.widget<Text>(
        find.byKey(InvitePeopleKeys.nearbyHeading),
      );

      expect(heading.style?.fontFamily, 'Poppins');
      expect(heading.style?.fontSize, 29);
      expect(heading.style?.fontWeight, FontWeight.w600);
      expect(body.style?.fontFamily, 'Poppins');
      expect(body.style?.fontSize, 14);
      expect(body.style?.fontWeight, FontWeight.w400);
      expect(nearby.style?.fontSize, 18);
      expect(nearby.style?.fontWeight, FontWeight.w600);
      expect(find.byType(InviteOptionTile), findsNWidgets(4));
      expect(find.byType(AppActionRow), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invite option containers keep exact 10px gaps and 20px before nearby heading',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      for (var index = 0; index < 3; index++) {
        final current = tester.getRect(
          find.byKey(InvitePeopleKeys.option(index)),
        );
        final next = tester.getRect(
          find.byKey(InvitePeopleKeys.option(index + 1)),
        );
        expect(next.top - current.bottom, closeTo(10, 0.01));
      }

      final last = tester.getRect(find.byKey(InvitePeopleKeys.option(3)));
      final nearby = tester.getRect(find.byKey(InvitePeopleKeys.nearbyHeading));
      expect(nearby.top - last.bottom, closeTo(20, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nearby people use reusable tiles and exact requested dimensions',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(NearbyPersonTile), findsNWidgets(3));
      expect(find.byType(SvgPicture), findsNWidgets(3));
      expect(find.text('Emma'), findsOneWidget);
      expect(find.text('2.1 km'), findsOneWidget);
      expect(find.text('Mike'), findsOneWidget);
      expect(find.text('3.4 km'), findsOneWidget);
      expect(find.text('Sophia'), findsOneWidget);
      expect(find.text('5.0 km'), findsOneWidget);

      for (var index = 0; index < 3; index++) {
        expect(
          tester.getSize(find.byKey(InvitePeopleKeys.image(index))),
          const Size(46, 46),
        );
        expect(
          tester.getSize(find.byKey(InvitePeopleKeys.add(index))),
          const Size(36, 36),
        );
      }

      final list = tester.widget<ListView>(
        find.byKey(InvitePeopleKeys.nearbyList),
      );
      expect(list.shrinkWrap, isTrue);
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('person add callback receives the correct model', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    NearbyPerson? added;
    await tester.pumpWidget(buildScreen(onAdd: (person) => added = person));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(InvitePeopleKeys.add(1)));
    await tester.pumpAndSettle();
    expect(find.byKey(InvitePeopleKeys.add(1)).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(InvitePeopleKeys.add(1)));
    await tester.pump();
    expect(added?.name, 'Mike');
  });

  testWidgets('SVG demo assets are bundled', (tester) async {
    await tester.pumpWidget(buildScreen());
    for (final asset in <String>[
      'assets/Emma.svg',
      'assets/Mike.svg',
      'assets/Sophia.svg',
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0));
    }
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Invite People is scroll-safe at ${size.width}x${size.height}',
      (tester) async {
        await setPhoneSize(tester, size);
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();
        expect(find.byKey(InvitePeopleKeys.heading), findsOneWidget);
        expect(find.byKey(InvitePeopleKeys.nearbyList), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('shared background remains #F9F9F9', () {
    expect(AppColors.background, const Color(0xFFF9F9F9));
  });
}
