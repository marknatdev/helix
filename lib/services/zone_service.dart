import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/zone.dart';
import 'admin_api.dart';

/// Talks to the /zones routes in functions/index.js and streams the `zones`
/// collection. Any signed-in user may create a zone and assign/unassign it
/// to helmets they own — the backend enforces ownership, not firestore.rules
/// (zones are server-write-only, same as `alerts`).
class ZoneService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Zone>> zonesStream() {
    return _db
        .collection('zones')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Zone.fromFirestore).toList());
  }

  Future<String?> _idToken() {
    return FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future.value(null);
  }

  Future<void> createZone({
    required String name,
    required String kind,
    required double centerLat,
    required double centerLng,
    required double radiusM,
  }) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/zones'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'kind': kind,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusM': radiusM,
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Zone creation failed');
    }
  }

  Future<void> deleteZone(String zoneId) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/zones/$zoneId/delete'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Zone delete failed');
    }
  }

  Future<void> assignHelmet({required String zoneId, required String helmetId}) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/zones/$zoneId/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'helmetId': helmetId}),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Assign failed');
    }
  }

  Future<void> unassignHelmet({required String zoneId, required String helmetId}) async {
    final token = await _idToken();
    if (token == null) throw StateError('Not signed in');

    final res = await http.post(
      Uri.parse('$adminApiBaseUrl/zones/$zoneId/unassign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'helmetId': helmetId}),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw StateError(body['error'] as String? ?? 'Unassign failed');
    }
  }
}
