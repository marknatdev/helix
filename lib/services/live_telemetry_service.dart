import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'admin_api.dart';

/// A single live telemetry reading pushed straight from the backend, ahead
/// of (and independent from) its Firestore write. See functions/index.js's
/// broadcastLiveTelemetry — this is a lower-latency overlay on top of the
/// Firestore-backed HelmetFeed, not a replacement for it: Firestore stays
/// the source of truth for history/alerts/worker-identity fields.
class LiveTelemetryReading {
  final String helmetId;
  final double lat;
  final double lng;
  final double speed;
  final double heading;
  final double battery;
  final double signal;
  final String status;

  LiveTelemetryReading({
    required this.helmetId,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.battery,
    required this.signal,
    required this.status,
  });

  factory LiveTelemetryReading.fromJson(Map<String, dynamic> j) {
    return LiveTelemetryReading(
      helmetId: j['helmetId'] as String,
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      speed: (j['speed'] as num?)?.toDouble() ?? 0,
      heading: (j['heading'] as num?)?.toDouble() ?? 0,
      battery: (j['battery'] as num?)?.toDouble() ?? -1,
      signal: (j['signal'] as num?)?.toDouble() ?? 0,
      status: j['status'] as String? ?? 'active',
    );
  }
}

/// Connects to the backend's /live WebSocket for near-instant telemetry
/// updates, bypassing the Firestore round-trip (and its write throttle) for
/// live display purposes. Auto-reconnects with backoff; the caller is
/// responsible for calling [connect] again whenever the ID token it holds
/// might be stale (e.g. after the user's claimed helmets change).
class LiveTelemetryService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<LiveTelemetryReading>.broadcast();
  Timer? _reconnectTimer;
  String? _lastToken;
  bool _disposed = false;

  Stream<LiveTelemetryReading> get readings => _controller.stream;

  Uri _wsUri(String token) {
    final httpUri = Uri.parse(adminApiBaseUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: '/live',
      queryParameters: {'token': token},
    );
  }

  void connect(String idToken) {
    _lastToken = idToken;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    try {
      _channel = WebSocketChannel.connect(_wsUri(idToken));
    } catch (e) {
      debugPrint('[LiveTelemetry] connect failed: $e');
      _scheduleReconnect();
      return;
    }
    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          if (msg['type'] == 'telemetry') {
            _controller.add(LiveTelemetryReading.fromJson(msg));
          }
        } catch (e) {
          debugPrint('[LiveTelemetry] bad message: $e');
        }
      },
      onError: (e) {
        debugPrint('[LiveTelemetry] stream error: $e');
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _lastToken == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed && _lastToken != null) connect(_lastToken!);
    });
  }

  void disconnect() {
    _lastToken = null;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }
}
