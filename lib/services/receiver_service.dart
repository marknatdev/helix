import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/receiver.dart';
import 'admin_api.dart';

/// Talks to the admin-only receiver-provisioning routes in functions/index.js
/// and streams the `receivers` collection.
class ReceiverService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Receiver>> receiversStream() {
    return _db
        .collection('receivers')
        .orderBy('provisionedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Receiver.fromFirestore).toList());
  }

  Future<String?> _idToken() {
    return FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future.value(null);
  }

  /// Provisions a new Receiver. Returns its receiverId and raw credential —
  /// the credential is shown to the caller exactly once; it is never stored
  /// and cannot be retrieved again. receiverId isn't secret (readable by any
  /// admin via firestore.rules `allow read: if isAdmin()`), just otherwise
  /// invisible in the UI, so it's returned too rather than only the
  /// credential.
  Future<(String receiverId, String credential)> provisionReceiver({
    required String hardwareId,
    String? label,
  }) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/admin/receivers/provision'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'hardwareId': hardwareId, 'label': label}),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw StateError(body['error'] as String? ?? 'Provisioning failed');
    }
    return (body['receiverId'] as String, body['credential'] as String);
  }

  Future<void> revokeReceiver(String receiverId) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/admin/receivers/$receiverId/revoke'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Revoke failed');
    }
  }
}
