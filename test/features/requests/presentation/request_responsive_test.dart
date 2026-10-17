import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/requests/domain/models/request_models.dart';
import 'package:orbit_ui/features/requests/presentation/screens/request_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in phoneSizes) {
    testWidgets('Request screen remains safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final people = List<RequestData>.generate(
        12,
        (index) => RequestData(
          id: 'person-$index',
          name: 'Person $index with a long backend name',
          supportingText:
              'Wants to Add as a friend with dynamic backend supporting text $index.',
          imagePath: index.isEven ? null : 'assets/Emma.png',
        ),
      );
      final circles = List<RequestData>.generate(
        12,
        (index) => RequestData(
          id: 'circle-$index',
          name: 'Circle $index with a long backend title',
          supportingText: 'Invited you to join this circle.',
          imagePath: index.isEven ? 'assets/Sophia.png' : null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RequestScreen(
            peopleRequests: people,
            circleRequests: circles,
            onBack: () {},
            onAccept: (_) {},
            onIgnore: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final scrollable = find.byKey(RequestScreenKeys.scrollView);
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
