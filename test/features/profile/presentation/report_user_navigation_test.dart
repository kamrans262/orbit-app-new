import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/core/navigation/app_fade_slide_page_route.dart';
import 'package:orbit_ui/features/profile/presentation/screens/report_user_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Report User opens with the established Orbit transition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open_report_user'),
                  onPressed: () {
                    Navigator.of(context).push(
                      AppFadeSlidePageRoute<void>(
                        builder: (_) => ReportUserScreen.forUser(
                          userId: 'mike',
                          displayName: 'Mike Smith',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open report'),
                ),
              ),
            );
          },
        ),
      ),
    );

    final opener = find.byKey(const Key('open_report_user'));
    expect(opener.hitTestable(), findsOneWidget);
    await tester.tap(opener.hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(ReportUserScreen), findsOneWidget);
    expect(find.text('Why are you reporting Mike Smith?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
