import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/user_privacy_entry.dart';
import 'package:orbit_ui/features/profile/presentation/screens/blocked_users_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Block Users matches reference structure and dimensions', (
    tester,
  ) async {
    await _pump(tester, const BlockUsersScreen());

    expect(find.text('Block Users'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Olivia'), findsOneWidget);
    expect(find.text('Oliviia'), findsOneWidget);
    expect(find.text('Block'), findsNWidgets(3));

    expect(BlockUserTile.referenceHeight, 67);
    expect(BlockUserTile.radius, 30);
    expect(BlockUserTile.avatarExtent, 50);
    expect(BlockUserTile.avatarToNameGap, 6);
    expect(BlockUserTile.buttonWidth, 73);
    expect(BlockUserTile.buttonHeight, 35);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Block requires confirmation and updates only selected user', (
    tester,
  ) async {
    final blocked = <String>[];
    await _pump(
      tester,
      BlockUsersScreen(
        onBlockRequested: (user) => blocked.add(user.id),
      ),
    );

    await tester.tap(find.byKey(BlockUsersKeys.action('emma')));
    await tester.pumpAndSettle();

    expect(find.text('Block Emma?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    final blockButtons = find.text('Block');
    await tester.tap(blockButtons.last);
    await tester.pumpAndSettle();

    expect(blocked, <String>['emma']);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Block'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, loading, and error states are supported', (tester) async {
    await _pump(tester, const BlockUsersScreen(users: <UserPrivacyEntry>[]));
    expect(find.text('No users to show'), findsOneWidget);

    await _pump(tester, const BlockUsersScreen(isLoading: true));
    expect(find.byKey(BlockUsersKeys.loadingState), findsOneWidget);

    await _pump(
      tester,
      const BlockUsersScreen(errorMessage: 'Connection failed'),
    );
    expect(find.text('Unable to load users'), findsOneWidget);
    expect(find.text('Connection failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('Block Users remains overflow-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longUser = UserPrivacyEntry(
        id: 'long',
        name: 'A very long localized backend display name that must ellipsize',
        avatarUrl: '',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: BlockUsersScreen(users: <UserPrivacyEntry>[longUser]),
        ),
      );
      await tester.pump();

      expect(find.byKey(BlockUsersKeys.scrollView), findsOneWidget);
      expect(find.textContaining('A very long'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}
