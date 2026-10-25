import 'dart:async';

/// Serializes mutation of the encrypted M6 outbox across fresh capture and
/// reconnect retry. Without this gate, reconnect could observe an original
/// before its required thumbnail/poster has been staged and create incomplete
/// grants. This is not a global network/background executor.
abstract final class OrbitMediaTransferGate {
  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final complete = Completer<void>();
    _tail = complete.future;
    await previous;
    try {
      return await operation();
    } finally {
      complete.complete();
    }
  }
}
