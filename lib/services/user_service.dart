import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'admin_api.dart';

/// Manages the current user's profile in Firestore (`users/{uid}`).
/// Tracks which helmet IDs the user has registered to their account.
class UserService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _uid;
  StreamSubscription? _sub;

  List<String> _helmetIds = [];
  List<String> get helmetIds => _helmetIds;

  /// Set only by an admin-invoked Cloud Function (see functions/index.js
  /// POST /admin/bootstrap) — never client-writable. See firestore.rules.
  String? _role;
  bool get isAdmin => _role == 'admin';

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Start listening to the user's document.
  void listen(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    _loaded = false;
    _helmetIds = [];
    _role = null;

    _sub = _db.collection('users').doc(uid).snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data != null && data['helmetIds'] is List) {
          _helmetIds = List<String>.from(data['helmetIds']);
        } else {
          _helmetIds = [];
        }
        _role = data != null ? data['role'] as String? : null;
        _loaded = true;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[UserService] Stream error: $e');
        _loaded = true;
        notifyListeners();
      },
    );
  }

  /// Stop listening (on sign-out).
  void clear() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _helmetIds = [];
    _role = null;
    _loaded = false;
    notifyListeners();
  }

  /// Claim a helmet using its pairing code (see spec-device-pairing-system.md,
  /// D1/D2). Calls the server-side Claim Cloud Function — never writes
  /// `helmetIds` directly from the client. No local state mutation is needed
  /// here: the `users/{uid}` snapshot listener above picks up the
  /// server-written `helmetIds` change automatically.
  Future<void> claimHelmet({
    required String helmetId,
    required String pairingCode,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/helmets/$helmetId/claim'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pairingCode': pairingCode}),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Claim failed');
    }
  }

  /// Release a claimed helmet (D4). Clears the server-side claim record, not
  /// just this account's `helmetIds` entry — an admin must re-provision a
  /// fresh pairing code before anyone can claim it again.
  Future<void> unclaimHelmet(String helmetId) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/helmets/$helmetId/unclaim'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Unclaim failed');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
