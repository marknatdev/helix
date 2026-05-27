import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'login_page.dart';

/// Shows [child] only when a user is signed in; otherwise shows [LoginPage].
/// Ensures the app does not auto-login — a fresh launch starts signed out
/// unless Firebase has a persisted session for the current device.
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthService, bool>((a) => a.isSignedIn);
    return signedIn ? child : const LoginPage();
  }
}
