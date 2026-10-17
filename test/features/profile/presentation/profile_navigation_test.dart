import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/profile/presentation/navigation/profile_navigation.dart';
import 'package:orbit_ui/features/profile/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('profile navigation returns the selected main tab', (
    tester,
  ) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  selected = await openProfileScreen(
                    context: context,
                    onAddPressed: () {},
                  );
                },
                child: const Text('Open Profile'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(selected, 0);
    expect(find.byType(ProfileScreen), findsNothing);
  });
}
