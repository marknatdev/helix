import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum HelmetStatus { active, idle, sos, offline }

String statusLabel(HelmetStatus s) {
  switch (s) {
    case HelmetStatus.active:
      return 'Active';
    case HelmetStatus.idle:
      return 'Idle';
    case HelmetStatus.sos:
      return 'SOS';
    case HelmetStatus.offline:
      return 'Offline';
  }
}

Color statusColor(HelmetStatus s) {
  switch (s) {
    case HelmetStatus.sos:
      return AppColors.statusSos;
    case HelmetStatus.offline:
      return AppColors.statusOffline;
    case HelmetStatus.idle:
      return AppColors.statusWarn;
    case HelmetStatus.active:
      return AppColors.statusOk;
  }
}

class Helmet {
  final String id;
  final String worker;
  final String role;
  final String crew;
  HelmetStatus status;
  double battery; // 0-100
  double signal; // 0-100
  double impactG;
  double lat;
  double lng;
  double heading; // deg
  double speed; // m/s
  DateTime lastSeen;
  int sinceSos; // seconds
  double rssi; // dBm (raw LoRa RSSI)
  double snr; // dB  (raw LoRa SNR)

  Helmet({
    required this.id,
    required this.worker,
    required this.role,
    required this.crew,
    required this.status,
    required this.battery,
    required this.signal,
    required this.impactG,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    required this.lastSeen,
    this.sinceSos = 0,
    this.rssi = 0,
    this.snr = 0,
  });

  /// Empty placeholder used for safe lookups.
  factory Helmet.empty() => Helmet(
        id: '',
        worker: '',
        role: '',
        crew: '',
        status: HelmetStatus.offline,
        battery: 0,
        signal: 0,
        impactG: 0,
        lat: 0,
        lng: 0,
        heading: 0,
        speed: 0,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Create a Helmet from a Firestore document snapshot.
  factory Helmet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Helmet(
      id: d['helmetId'] as String? ?? doc.id,
      worker: d['worker'] as String? ?? '',
      role: d['role'] as String? ?? '',
      crew: d['crew'] as String? ?? '',
      status: _parseStatus(d['status'] as String? ?? 'offline'),
      battery: (d['battery'] as num?)?.toDouble() ?? 0,
      signal: (d['signal'] as num?)?.toDouble() ?? 0,
      impactG: (d['impactG'] as num?)?.toDouble() ?? 0,
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      heading: (d['heading'] as num?)?.toDouble() ?? 0,
      speed: (d['speed'] as num?)?.toDouble() ?? 0,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sinceSos: (d['sinceSos'] as num?)?.toInt() ?? 0,
      rssi: (d['rssi'] as num?)?.toDouble() ?? 0,
      snr: (d['snr'] as num?)?.toDouble() ?? 0,
    );
  }

  static HelmetStatus _parseStatus(String s) {
    switch (s) {
      case 'active':
        return HelmetStatus.active;
      case 'idle':
        return HelmetStatus.idle;
      case 'sos':
        return HelmetStatus.sos;
      case 'offline':
      default:
        return HelmetStatus.offline;
    }
  }

  String get initials =>
      worker.split(' ').map((p) => p.isEmpty ? '' : p[0]).join();

  /// True if the helmet hasn't been seen for more than 5 minutes.
  /// Use this for UI status instead of the stored status field.
  bool get isOffline {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    return lastSeen.isBefore(cutoff);
  }

  /// Effective status considering lastSeen time.
  HelmetStatus get effectiveStatus {
    if (isOffline) return HelmetStatus.offline;
    return status;
  }
}

enum AlertKind { sos, impact, geofence, battery, offline, fall }

String alertKindLabel(AlertKind k) {
  switch (k) {
    case AlertKind.sos:
      return 'SOS';
    case AlertKind.impact:
      return 'Impact';
    case AlertKind.geofence:
      return 'Geofence';
    case AlertKind.battery:
      return 'Battery';
    case AlertKind.offline:
      return 'Offline';
    case AlertKind.fall:
      return 'Fall';
  }
}

Color alertKindColor(AlertKind k) {
  switch (k) {
    case AlertKind.sos:
    case AlertKind.impact:
      return AppColors.statusSos;
    case AlertKind.fall:
    case AlertKind.geofence:
    case AlertKind.battery:
      return AppColors.statusWarn;
    case AlertKind.offline:
      return AppColors.statusOffline;
  }
}

IconData alertKindIcon(AlertKind k) {
  switch (k) {
    case AlertKind.sos:
      return Icons.shield_outlined;
    case AlertKind.impact:
      return Icons.flash_on;
    case AlertKind.fall:
      return Icons.warning_amber_rounded;
    case AlertKind.geofence:
      return Icons.gps_fixed;
    case AlertKind.battery:
      return Icons.battery_alert;
    case AlertKind.offline:
      return Icons.wifi_off;
  }
}

class AlertEvent {
  final String id;
  final String helmetId;
  final String worker;
  final AlertKind kind;
  final String message;
  final DateTime ts;
  bool resolved;

  AlertEvent({
    required this.id,
    required this.helmetId,
    required this.worker,
    required this.kind,
    required this.message,
    required this.ts,
    this.resolved = false,
  });

  /// Create an AlertEvent from a Firestore document snapshot.
  factory AlertEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AlertEvent(
      id: doc.id,
      helmetId: d['helmetId'] as String? ?? '',
      worker: d['worker'] as String? ?? '',
      kind: _parseAlertKind(d['kind'] as String? ?? 'offline'),
      message: d['message'] as String? ?? '',
      ts: (d['ts'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolved: d['resolved'] as bool? ?? false,
    );
  }

  static AlertKind _parseAlertKind(String s) {
    switch (s) {
      case 'sos':
        return AlertKind.sos;
      case 'impact':
        return AlertKind.impact;
      case 'geofence':
        return AlertKind.geofence;
      case 'battery':
        return AlertKind.battery;
      case 'fall':
        return AlertKind.fall;
      case 'offline':
      default:
        return AlertKind.offline;
    }
  }
}

String timeAgo(DateTime ts) {
  final diff = DateTime.now().difference(ts);
  final s = diff.inSeconds;
  if (s < 60) return '${s}s ago';
  final m = diff.inMinutes;
  if (m < 60) return '${m}m ago';
  final h = diff.inHours;
  return '${h}h ago';
}
