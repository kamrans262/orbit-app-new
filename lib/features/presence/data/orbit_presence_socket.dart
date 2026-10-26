import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'orbit_presence_repository.dart';
import 'orbit_presence_rollout.dart';

/// Optional WSS client for a separately provisioned, authenticated gateway.
/// The gateway protocol is documented in M9 handoff; no default socket exists.
class OrbitPresenceSocket {
  OrbitPresenceSocket({OrbitPresenceRepository? repository})
      : _repository = repository ?? OrbitPresenceRepository();

  final OrbitPresenceRepository _repository;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _renewal;
  int _epoch = 0;
  bool _authorized = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _authorized && _socket != null;

  Future<void> connect() async {
    final endpoint = OrbitPresenceRollout.secureGateway;
    if (endpoint == null) return; // Fail closed until WSS is provisioned.
    await stop();
    final epoch = ++_epoch;
    WebSocket? socket;
    try {
      // A ticket never goes into URL/query parameters, analytics or storage.
      final credentials = await _repository.ticket();
      final ticket = credentials['ticket'];
      if (ticket is! String || ticket.length < 40 || epoch != _epoch) return;
      socket = await WebSocket.connect(endpoint.toString())
          .timeout(const Duration(seconds: 8));
      if (epoch != _epoch) { await socket.close(); return; }
      _socket = socket;
      _authorized = false;
      socket.add(jsonEncode({'type':'auth','ticket':ticket}));
      _subscription = socket.listen((value) {
        if (value is! String || value.length > 16000) return;
        try {
          final decoded=jsonDecode(value);
          if (decoded is! Map) return;
          final data=Map<String, dynamic>.from(decoded);
          if (data['type']=='authenticated') {
            _authorized=true;
            return;
          }
          if (!_authorized) return;
          if (data['event'] is Map) {
            final event=Map<String,dynamic>.from(data['event'] as Map);
            if (event['circle_id'] is String) _events.add(event);
          }
        } catch (_) {
          // Invalid gateway messages are ignored; never trust them as status.
        }
      },onDone: _disconnected, onError: (_) => _disconnected());
      // Reconnect with a new backend-signed session ticket before expiry.
      _renewal = Timer(const Duration(seconds: 45), () {
        if (epoch == _epoch) unawaited(connect());
      });
    } catch (_) {
      if (socket != null) { try { await socket.close(); } catch (_) {} }
      _disconnected();
    }
  }

  void _disconnected() {
    _authorized = false;
    // Do not display stale Presence once a transport disconnects.
    _events.add({'type':'presence.transport_down','circle_id':'*'});
  }

  void send(String kind, Map<String, Object?> data) {
    if (!connected) return;
    _socket!.add(jsonEncode({'type':kind,...data}));
  }

  Future<void> stop() async {
    _epoch++;
    _renewal?.cancel(); _renewal=null;
    await _subscription?.cancel(); _subscription=null;
    final socket=_socket; _socket=null; _authorized=false;
    if (socket!=null) { try { await socket.close(); } catch (_) {} }
  }
}
