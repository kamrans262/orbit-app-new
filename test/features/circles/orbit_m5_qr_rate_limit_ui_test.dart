import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/circles/data/orbit_circle_repository.dart';
import 'package:orbit_ui/features/circles/presentation/screens/orbit_circle_join_screen.dart';

class _LimitedQrRepository extends OrbitCircleRepository {
  int previewCalls = 0;

  @override
  Future<Map<String, dynamic>> previewCode(String input) async {
    previewCalls++;
    throw OrbitIdentityException('Too Many Attempts.', 429);
  }
}

void main() {
  testWidgets('Circle QR join handles rate limit without requesting again',
      (tester) async {
    final repository = _LimitedQrRepository();
    await tester.pumpWidget(MaterialApp(
      home: OrbitCircleJoinScreen(repository: repository),
    ));
    await tester.enterText(
      find.byKey(const Key('m5_join_code_field')),
      'A' * 40,
    );
    await tester.tap(find.byKey(const Key('m5_join_verify')));
    await tester.pumpAndSettle();
    expect(repository.previewCalls, 1);
    expect(find.textContaining('about a minute'), findsOneWidget);

    await tester.tap(find.byKey(const Key('m5_join_verify')));
    await tester.pumpAndSettle();
    expect(repository.previewCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
