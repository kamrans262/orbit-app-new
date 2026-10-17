import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/app/app.dart';
import 'package:orbit_ui/features/welcome/presentation/screens/welcome2_screen.dart';

void main() {
  testWidgets('Get Started opens the second welcome screen', (tester) async {
    await tester.pumpWidget(const OrbitApp());
    await tester.pump();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byType(Welcome2Screen), findsOneWidget);
    expect(find.text('Live. Share. Protect'), findsOneWidget);
  });
}
