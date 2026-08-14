import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/helmet.dart';

/// Thin wrapper around Firestore that exposes real-time streams for
/// helmet telemetry and alert documents.
class FirestoreHelmetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of helmets filtered by the given IDs (max 30 for Firestore whereIn).
  /// If [helmetIds] is empty, returns an empty stream.
  Stream<List<Helmet>> helmetsStream({List<String> helmetIds = const []}) {
    if (helmetIds.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('helmets')
        .where(FieldPath.documentId, whereIn: helmetIds)
        .snapshots()
        .map((snap) => snap.docs.map(Helmet.fromFirestore).toList());
  }

  /// Stream of alerts filtered by the given helmet IDs.
  /// If [helmetIds] is empty, returns an empty stream.
  Stream<List<AlertEvent>> alertsStream({List<String> helmetIds = const []}) {
    if (helmetIds.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('alerts')
        .where('helmetId', whereIn: helmetIds)
        .orderBy('ts', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AlertEvent.fromFirestore).toList());
  }

  /// Mark a single alert as resolved.
  Future<void> acknowledgeAlert(String alertId) {
    return _db.collection('alerts').doc(alertId).update({'resolved': true});
  }

  /// Mark all unresolved alerts for the given helmet IDs as resolved.
  /// Scoped to [helmetIds] so a user can only resolve their own alerts.
  Future<void> acknowledgeAllAlerts(List<String> helmetIds) async {
    if (helmetIds.isEmpty) return;
    final snap = await _db
        .collection('alerts')
        .where('helmetId', whereIn: helmetIds)
        .where('resolved', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'resolved': true});
    }
    await batch.commit();
  }
}
