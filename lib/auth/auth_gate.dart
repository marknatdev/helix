import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'login_page.dart';

/// Shows [child] only when a user is signed in; otherwise shows [LoginPage].
/// Ensures the app does not auto-login — a fresh launch starts signed out
/// unless Firebase has a persisted session for the current device.
class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authServiceProvider.select((a) => a.isSignedIn));
    return signedIn ? child : const LoginPage();
  }
}
