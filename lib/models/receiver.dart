import 'package:cloud_firestore/cloud_firestore.dart';

enum ReceiverState { active, revoked }

ReceiverState _parseReceiverState(String s) {
  switch (s) {
    case 'revoked':
      return ReceiverState.revoked;
    case 'active':
    default:
      return ReceiverState.active;
  }
}

String receiverStateLabel(ReceiverState s) {
  switch (s) {
    case ReceiverState.active:
      return 'Active';
    case ReceiverState.revoked:
      return 'Revoked';
  }
}

/// A provisioned Receiver gateway (`receivers/{receiverId}`).
/// The credential verifier hash never appears here — it lives in a
/// server-only `private` subcollection no client rule ever grants read on.
class Receiver {
  final String id;
  final String hardwareId;
  final String label;
  final ReceiverState state;
  final DateTime? lastSeen;
  final DateTime? provisionedAt;
  final String? provisionedBy;

  Receiver({
    required this.id,
    required this.hardwareId,
    required this.label,
    required this.state,
    this.lastSeen,
    this.provisionedAt,
    this.provisionedBy,
  });

  factory Receiver.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Receiver(
      id: doc.id,
      hardwareId: d['hardwareId'] as String? ?? '',
      label: d['label'] as String? ?? doc.id,
      state: _parseReceiverState(d['state'] as String? ?? 'active'),
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      provisionedAt: (d['provisionedAt'] as Timestamp?)?.toDate(),
      provisionedBy: d['provisionedBy'] as String?,
    );
  }
}
