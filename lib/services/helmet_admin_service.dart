import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'admin_api.dart';

/// Talks to the admin-only helmet-provisioning route in functions/index.js.
/// Unlike receivers (firestore.rules grants admins `allow read: if isAdmin()`
/// on the whole collection), `helmets/{helmetId}` only grants read to the
/// claiming owner — there is no admin bypass — so this service has no
/// `provisionedStream()` counterpart to ReceiverService's; the admin UI can
/// only show what it provisions in the current session, not a persisted list.
class HelmetAdminService {
  Future<String?> _idToken() {
    return FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future.value(null);
  }

  /// Provisions a new helmet. Returns the raw pairing code — shown to the
  /// caller exactly once; only its hash is stored server-side and it cannot
  /// be retrieved again (re-provisioning the same unclaimed helmetId issues
  /// a fresh code and invalidates the old one).
  Future<String> provisionHelmet({
    required String helmetId,
    String? label,
  }) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/admin/helmets/provision'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'helmetId': helmetId, 'label': label}),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw StateError(body['error'] as String? ?? 'Provisioning failed');
    }
    return body['pairingCode'] as String;
  }
}
