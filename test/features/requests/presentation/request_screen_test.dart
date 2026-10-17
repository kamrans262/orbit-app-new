import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/requests/domain/models/request_models.dart';
import 'package:orbit_ui/features/requests/presentation/screens/request_screen.dart';
import 'package:orbit_ui/features/requests/presentation/widgets/request_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const people = <RequestData>[
    RequestData(
      id: 'person-1',
      name: 'Mike',
      supportingText: 'Wants to Add as a friend.',
      imagePath: 'assets/Mike.png',
    ),
    RequestData(
      id: 'person-2',
      name: 'Sophia',
      supportingText: 'Wants to Add as a friend.',
      imagePath: 'assets/Sophia.png',
    ),
  ];

  const circles = <RequestData>[
    RequestData(
      id: 'circle-1',
      name: 'Weekend crew',
      supportingText: 'Invited you to join this circle.',
      imagePath: 'assets/Emma.png',
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    List<RequestData> peopleRequests = people,
    List<RequestData> circleRequests = circles,
    RequestViewState state = RequestViewState.loaded,
    Future<void> Function(RequestData)? onAccept,
    Future<void> Function(RequestData)? onIgnore,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RequestScreen(
          peopleRequests: peopleRequests,
          circleRequests: circleRequests,
          onBack: () {},
          onAccept: onAccept ?? (_) async {},
          onIgnore: onIgnore ?? (_) async {},
          viewState: state,
        ),
      ),
    );
    // Loading intentionally animates indefinitely. pumpAndSettle would time
    // out in the loading-state test, so deliver the initial frame only here.
    // Tests of finite card removal animations settle after their own actions.
    await tester.pump();
  }

  testWidgets('renders shared header and both dynamic sections', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Request'), findsOneWidget);
    expect(find.byKey(RequestScreenKeys.backButton), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Circles'), findsOneWidget);
    expect(find.byKey(RequestCardKeys.card('person-1')), findsOneWidget);
    expect(find.byKey(RequestCardKeys.card('circle-1')), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('accept calls backend callback then removes request smoothly', (
    tester,
  ) async {
    RequestData? accepted;
    await pumpScreen(
      tester,
      onAccept: (request) async {
        accepted = request;
      },
    );

    await tester.tap(find.byKey(RequestCardKeys.accept('person-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(accepted?.id, 'person-1');
    expect(find.byKey(RequestCardKeys.card('person-1')), findsNothing);
    expect(find.byKey(RequestCardKeys.card('person-2')), findsOneWidget);
  });

  testWidgets('ignore calls backend callback and removes circle request', (
    tester,
  ) async {
    RequestData? ignored;
    await pumpScreen(
      tester,
      onIgnore: (request) async {
        ignored = request;
      },
    );

    await tester.ensureVisible(find.byKey(RequestCardKeys.ignore('circle-1')));
    await tester.tap(find.byKey(RequestCardKeys.ignore('circle-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(ignored?.id, 'circle-1');
    expect(find.byKey(RequestCardKeys.card('circle-1')), findsNothing);
  });

  testWidgets('supports loading error and section empty states', (
    tester,
  ) async {
    await pumpScreen(tester, state: RequestViewState.loading);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpScreen(tester, state: RequestViewState.error);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );

    await pumpScreen(
      tester,
      peopleRequests: const <RequestData>[],
      circleRequests: const <RequestData>[],
    );
    expect(find.text('No people requests right now.'), findsOneWidget);
    expect(find.text('No circle requests right now.'), findsOneWidget);
  });

  testWidgets('missing avatar and long backend text stay overflow-safe', (
    tester,
  ) async {
    const longRequest = RequestData(
      id: 'long',
      name: 'A very long backend-provided person name that must remain safe on compact phones',
      supportingText: 'A very long backend-generated request explanation that must wrap safely without breaking the card layout or the action buttons.',
    );

    await pumpScreen(
      tester,
      size: const Size(320, 568),
      peopleRequests: const <RequestData>[longRequest],
      circleRequests: const <RequestData>[],
    );

    expect(find.byKey(RequestCardKeys.avatarFallback('long')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
