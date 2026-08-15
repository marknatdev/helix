import 'package:cloud_firestore/cloud_firestore.dart';

/// A geofenced work-site zone. Created/assigned via the /zones routes in
/// functions/index.js — never written directly by the client (see
/// firestore.rules). `containment` tracks the last-known inside/outside
/// state per assigned helmet, kept in sync by the backend's geofence check
/// on every /lora-uplink.
class Zone {
  final String id;
  final String name;
  final String kind;
  final double centerLat;
  final double centerLng;
  final double radiusM;
  final List<String> assignedHelmetIds;
  final Map<String, bool> containment;
  final String createdBy;

  Zone({
    required this.id,
    required this.name,
    required this.kind,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.assignedHelmetIds,
    required this.containment,
    required this.createdBy,
  });

  factory Zone.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final containmentRaw = d['containment'];
    return Zone(
      id: doc.id,
      name: d['name'] as String? ?? 'Unnamed zone',
      kind: d['kind'] as String? ?? 'operational',
      centerLat: (d['centerLat'] as num?)?.toDouble() ?? 0,
      centerLng: (d['centerLng'] as num?)?.toDouble() ?? 0,
      radiusM: (d['radiusM'] as num?)?.toDouble() ?? 0,
      assignedHelmetIds: d['assignedHelmetIds'] is List
          ? List<String>.from(d['assignedHelmetIds'])
          : [],
      containment: containmentRaw is Map
          ? containmentRaw.map((k, v) => MapEntry(k as String, v == true))
          : {},
      createdBy: d['createdBy'] as String? ?? '',
    );
  }

  /// null = unknown/no reading yet, true = inside, false = outside.
  bool? containmentFor(String helmetId) => containment[helmetId];
}
