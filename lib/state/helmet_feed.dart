import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/helmet.dart';
import '../services/firestore_helmet_service.dart';

/// Live helmet telemetry feed backed by Firestore real-time streams.
/// Only streams helmets registered to the current user.
class HelmetFeed extends ChangeNotifier {
  final FirestoreHelmetService _service = FirestoreHelmetService();

  List<Helmet> helmets = [];
  List<AlertEvent> alerts = [];

  StreamSubscription? _helmetsSub;
  StreamSubscription? _alertsSub;

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
    await _service.acknowledgeAllAlerts();
  }

  @override
  void dispose() {
    _helmetsSub?.cancel();
    _alertsSub?.cancel();
    super.dispose();
  }
}
