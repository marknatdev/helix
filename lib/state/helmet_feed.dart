import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/helmet.dart';
import '../services/firestore_helmet_service.dart';
import '../services/live_telemetry_service.dart';

/// Live helmet telemetry feed backed by Firestore real-time streams, with a
/// WebSocket overlay (see live_telemetry_service.dart) that updates
/// position/vitals in memory the instant a reading arrives at the backend —
/// ahead of, and independent from, its throttled Firestore write. Firestore
/// remains the source of truth for alerts and anything the WS payload
/// doesn't carry (worker/role/crew, claim state, etc.); the WS overlay only
/// ever mutates fields on helmets already present from the Firestore
/// stream, it never adds/removes helmets itself.
class HelmetFeed extends ChangeNotifier {
  final FirestoreHelmetService _service = FirestoreHelmetService();
  final LiveTelemetryService _live = LiveTelemetryService();

  List<Helmet> helmets = [];
  List<AlertEvent> alerts = [];

  StreamSubscription? _helmetsSub;
  StreamSubscription? _alertsSub;
  StreamSubscription? _liveSub;

  HelmetFeed() {
    _liveSub = _live.readings.listen(_applyLiveReading);
  }

  String? _liveAttachedUid;

  /// Call whenever the signed-in user's uid changes (sign in/out). Guarded
  /// on uid, not the token itself, since the token is refetched by the
  /// caller on every rebuild but only actually needs reconnecting when the
  /// signed-in user changes. Pass uid: null, idToken: null to disconnect.
  void attachLiveTelemetry(String? uid, String? idToken) {
    if (uid == _liveAttachedUid) return;
    _liveAttachedUid = uid;
    if (idToken == null) {
      _live.disconnect();
    } else {
      _live.connect(idToken);
    }
  }

  void _applyLiveReading(LiveTelemetryReading r) {
    final idx = helmets.indexWhere((h) => h.id == r.helmetId);
    if (idx == -1) return; // not one of ours (or not loaded yet) — ignore
    final h = helmets[idx];
    h.lat = r.lat;
    h.lng = r.lng;
    h.speed = r.speed;
    h.heading = r.heading;
    if (r.battery >= 0) h.battery = r.battery;
    h.signal = r.signal;
    h.status = parseHelmetStatus(r.status);
    // Bump lastSeen so effectiveStatus doesn't flip to "offline" after 5
    // minutes just because the throttled Firestore write hasn't landed —
    // the WS reading itself proves the helmet is live right now.
    h.lastSeen = DateTime.now();
    notifyListeners();
  }

  /// The helmet IDs currently being listened to.
  List<String> _activeIds = [];

  /// True while waiting for the first snapshot after subscribing.
  bool _loading = false;
  bool get loading => _loading;

  /// True once the first helmets snapshot has arrived.
  bool _connected = false;
  bool get connected => _connected;

  /// Last error from the Firestore streams, if any.
  String? _error;
  String? get error => _error;

  /// Call whenever the user's registered helmet IDs change.
  /// Re-subscribes the Firestore streams to the new set of IDs.
  void updateHelmetIds(List<String> ids) {
    // Avoid re-subscribing if the list hasn't changed.
    if (listEquals(ids, _activeIds)) return;
    _activeIds = List.of(ids);

    _helmetsSub?.cancel();
    _alertsSub?.cancel();

    if (ids.isEmpty) {
      helmets = [];
      alerts = [];
      _loading = false;
      _connected = true;
      _error = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _connected = false;
    notifyListeners();

    _helmetsSub = _service.helmetsStream(helmetIds: ids).listen(
      (list) {
        helmets = list;
        _loading = false;
        _connected = true;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = 'Helmets stream error: $e';
        notifyListeners();
      },
    );
    _alertsSub = _service.alertsStream(helmetIds: ids).listen(
      (list) {
        alerts = list;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Alerts stream error: $e';
        notifyListeners();
      },
    );
  }

  /// Mark a single alert as resolved (writes to Firestore).
  Future<void> acknowledge(String alertId) async {
    await _service.acknowledgeAlert(alertId);
  }

  /// Mark all unresolved alerts as resolved (batch write to Firestore).
  Future<void> acknowledgeAll() async {
    await _service.acknowledgeAllAlerts(_activeIds);
  }

  @override
  void dispose() {
    _helmetsSub?.cancel();
    _alertsSub?.cancel();
    _liveSub?.cancel();
    _live.dispose();
    super.dispose();
  }
}
