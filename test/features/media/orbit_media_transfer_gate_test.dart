import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_media_transfer_gate.dart';

void main() {
  test('new capture and offline recovery cannot mutate outbox together', () async {
    final holdFirst = Completer<void>();
    final events = <String>[];
    final first = OrbitMediaTransferGate.run(() async {
      events.add('capture started');
      await holdFirst.future;
      events.add('capture finished');
    });
    final retry = OrbitMediaTransferGate.run(() async {
      events.add('retry started');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, <String>['capture started']);
    holdFirst.complete();
    await Future.wait(<Future<void>>[first, retry]);
    expect(events, <String>[
      'capture started',
      'capture finished',
      'retry started',
    ]);
  });

  test('queue recovers when one operation fails', () async {
    await expectLater(
      OrbitMediaTransferGate.run(() async => throw StateError('offline')),
      throwsStateError,
    );
    expect(await OrbitMediaTransferGate.run(() async => 42), 42);
  });
}
