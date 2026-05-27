import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helix_command_center/models/helmet.dart';

// Fake DocumentSnapshot using mockito or a manual subclass
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic operator [](Object key) => _data?[key];

  @override
  dynamic get(Object key) => _data?[key];

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
}

void main() {
  group('Helmet Model Tests', () {
    test('Default/Empty factory builds offline helmet', () {
      final h = Helmet.empty();
      expect(h.id, isEmpty);
      expect(h.status, HelmetStatus.offline);
      expect(h.effectiveStatus, HelmetStatus.offline);
    });

    test('fromFirestore correctly parses active helmet fields', () {
      final now = DateTime.now();
      final snap = FakeDocumentSnapshot('HLX-999', {
        'helmetId': 'HLX-999',
        'worker': 'Jane Doe',
        'role': 'Engineer',
        'crew': 'Crew C',
        'status': 'active',
        'battery': 95.0,
        'signal': 85.0,
        'impactG': 0.1,
        'lat': 13.75,
        'lng': 100.5,
        'heading': 180.0,
        'speed': 1.5,
        'lastSeen': Timestamp.fromDate(now),
        'sinceSos': 0,
        'rssi': -70.0,
        'snr': 9.0,
      });

      final h = Helmet.fromFirestore(snap);
      expect(h.id, 'HLX-999');
      expect(h.worker, 'Jane Doe');
      expect(h.role, 'Engineer');
      expect(h.crew, 'Crew C');
      expect(h.status, HelmetStatus.active);
      expect(h.battery, 95.0);
      expect(h.signal, 85.0);
      expect(h.impactG, 0.1);
      expect(h.lat, 13.75);
      expect(h.lng, 100.5);
      expect(h.heading, 180.0);
      expect(h.speed, 1.5);
      expect(h.rssi, -70.0);
      expect(h.snr, 9.0);
      expect(h.effectiveStatus, HelmetStatus.active);
    });

    test('effectiveStatus correctly calculates offline status after 5 minutes', () {
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 6));
      final snap = FakeDocumentSnapshot('HLX-999', {
        'status': 'active',
        'lastSeen': Timestamp.fromDate(fiveMinAgo),
      });

      final h = Helmet.fromFirestore(snap);
      expect(h.status, HelmetStatus.active);
      expect(h.isOffline, isTrue);
      expect(h.effectiveStatus, HelmetStatus.offline);
    });

    test('effectiveStatus retains SOS status if within time limit', () {
      final now = DateTime.now();
      final snap = FakeDocumentSnapshot('HLX-999', {
        'status': 'sos',
        'lastSeen': Timestamp.fromDate(now),
      });

      final h = Helmet.fromFirestore(snap);
      expect(h.status, HelmetStatus.sos);
      expect(h.isOffline, isFalse);
      expect(h.effectiveStatus, HelmetStatus.sos);
    });
  });

  group('AlertEvent Model Tests', () {
    test('fromFirestore correctly parses AlertEvent parameters', () {
      final now = DateTime.now();
      final snap = FakeDocumentSnapshot('ALERT-123', {
        'helmetId': 'HLX-111',
        'worker': 'John Smith',
        'kind': 'sos',
        'message': 'Manual SOS trigger',
        'ts': Timestamp.fromDate(now),
        'resolved': false,
      });

      final alert = AlertEvent.fromFirestore(snap);
      expect(alert.id, 'ALERT-123');
      expect(alert.helmetId, 'HLX-111');
      expect(alert.worker, 'John Smith');
      expect(alert.kind, AlertKind.sos);
      expect(alert.message, 'Manual SOS trigger');
      expect(alert.resolved, isFalse);
    });
  });
}
