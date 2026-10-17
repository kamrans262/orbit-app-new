import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/domain/models/edit_profile_models.dart';
import 'package:orbit_ui/features/profile/domain/models/profile_models.dart';
import 'package:orbit_ui/features/profile/presentation/screens/edit_profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = ProfileData(
    id: 'emma',
    name: 'Emma ⭐',
    bio: 'Good vibes only',
    imagePath: 'assets/Emma.png',
    circleCount: 10,
    friendCount: 24,
    momentCount: 120,
    moments: <ProfileMomentData>[],
  );

  testWidgets(
    'Edit Profile matches demo values and exposes photo source choices',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: EditProfileScreen(profile: profile)),
      );
      await tester.pump();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Photo'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('User Name'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields[0].controller?.text, 'Emma Shan');
      expect(fields[1].controller?.text, 'Emma');

      await tester.tap(find.byKey(EditProfileKeys.changePhoto));
      await tester.pumpAndSettle();
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Edit Profile validates and submits a backend-ready request', (
    tester,
  ) async {
    UpdateProfileRequest? request;

    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          profile: profile,
          onSave: (value) async {
            request = value;
          },
        ),
      ),
    );
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Emma Shan');
    await tester.enterText(fields.at(1), 'emma.shan');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(request?.fullName, 'Emma Shan');
    expect(request?.username, 'emma.shan');
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 866),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Edit Profile is overflow-safe at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: EditProfileScreen(
              profile: profile,
              initialFullName: 'A Long Backend User Name That Must Stay Reachable On Small Phones',
              initialUsername: 'long.backend.username',
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(EditProfileKeys.usernameField));
        await tester.pump();
        await tester.drag(
          find.byKey(EditProfileKeys.scrollView),
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(EditProfileKeys.saveButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
