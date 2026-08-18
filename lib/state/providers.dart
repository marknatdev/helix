import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../auth/auth_service.dart';
import '../models/zone.dart';
import '../services/user_service.dart';
import '../services/zone_service.dart';
import 'helmet_feed.dart';

/// App-wide Riverpod providers wrapping the existing ChangeNotifier state
/// classes. The classes themselves are unchanged — only how widgets reach
/// them changed, from package:provider's InheritedWidget lookup to
/// Riverpod's ProviderScope.
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) => AuthService());
final userServiceProvider = ChangeNotifierProvider<UserService>((ref) => UserService());
final helmetFeedProvider = ChangeNotifierProvider<HelmetFeed>((ref) => HelmetFeed());
final zoneServiceProvider = ChangeNotifierProvider<ZoneService>((ref) => ZoneService());
final zonesStreamProvider = StreamProvider<List<Zone>>((ref) {
  return ref.watch(zoneServiceProvider).zonesStream();
});

/// Light/dark preference, persisted in localStorage so it survives reloads.
///
/// The palette itself lives in mutable statics (see AppColors), so flipping
/// this provider only matters because HelixApp watches it above MaterialApp:
/// that rebuild re-runs AppColors.apply() and rebuilds the whole tree with
/// the new values.
class ThemeModeNotifier extends StateNotifier<bool> {
  static const _storageKey = 'helix.theme.light';

  ThemeModeNotifier() : super(_read());

  static bool _read() {
    try {
      return web.window.localStorage.getItem(_storageKey) == 'true';
    } catch (_) {
      return false; // non-web or storage blocked — fall back to dark
    }
  }

  /// True when the light palette is selected.
  bool get isLight => state;

  void toggle() => setLight(!state);

  void setLight(bool light) {
    state = light;
    try {
      web.window.localStorage.setItem(_storageKey, light ? 'true' : 'false');
    } catch (_) {
      // Preference just won't persist; the in-session switch still works.
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) => ThemeModeNotifier());
