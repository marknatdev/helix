import 'package:flutter_riverpod/flutter_riverpod.dart';

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
