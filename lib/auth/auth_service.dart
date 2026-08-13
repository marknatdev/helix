import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around FirebaseAuth exposing a ChangeNotifier so UI can
/// react to auth state changes via provider.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final StreamSubscription<User?> _authSub;

  AuthService() {
    _authSub = _auth.authStateChanges().listen((_) => notifyListeners());
  }

  User? get user => _auth.currentUser;
  bool get isSignedIn => user != null;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Human readable error for UI.
  static String messageFor(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account with that email already exists.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is disabled in Firebase console.';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    return 'Authentication failed: $e';
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
