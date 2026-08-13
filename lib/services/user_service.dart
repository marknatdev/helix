import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Manages the current user's profile in Firestore (`users/{uid}`).
/// Tracks which helmet IDs the user has registered to their account.
class UserService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _uid;
  StreamSubscription? _sub;

  List<String> _helmetIds = [];
  List<String> get helmetIds => _helmetIds;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Start listening to the user's document.
  void listen(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    _loaded = false;
    _helmetIds = [];

    _sub = _db.collection('users').doc(uid).snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data != null && data['helmetIds'] is List) {
          _helmetIds = List<String>.from(data['helmetIds']);
        } else {
          _helmetIds = [];
        }
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
    _loaded = false;
    notifyListeners();
  }

  /// Register a helmet ID to the current user.
  Future<void> registerHelmet(String helmetId) async {
    if (_uid == null) return;
    final id = helmetId.trim().toUpperCase();
    if (id.isEmpty || _helmetIds.contains(id)) return;

    await _db.collection('users').doc(_uid).set({
      'helmetIds': FieldValue.arrayUnion([id]),
    }, SetOptions(merge: true));
  }

  /// Unregister a helmet ID from the current user.
  Future<void> unregisterHelmet(String helmetId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'helmetIds': FieldValue.arrayRemove([helmetId]),
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
