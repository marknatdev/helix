import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;

import 'auth/auth_gate.dart';
import 'auth/auth_service.dart';
import 'firebase_options.dart';
import 'models/helmet.dart';
import 'services/user_service.dart';
import 'state/helmet_feed.dart';
import 'theme/app_theme.dart';
import 'views/fleet_view.dart';
import 'views/incidents_view.dart';
import 'views/live_view.dart';
import 'views/reports_view.dart';
import 'views/zones_view.dart';
import 'widgets/command_header.dart';
import 'widgets/settings_dialog.dart';

/// Site name shown in the header and map HUD.
const String kSiteName = 'PIER-27';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF121418),
        body: Center(
          child: Text('Init error: $e',
              style: const TextStyle(color: Colors.red, fontSize: 14)),
        ),
      ),
    ));
    return;
  }
  runApp(const HelixApp());
}

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UserService()),
        ChangeNotifierProvider(create: (_) => HelmetFeed()),
      ],
      child: MaterialApp(
        title: 'HELIX · Smart Helmet Command Center',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(child: _UserHelmetBridge()),
      ),
    );
  }
}

/// Bridges AuthService → UserService → HelmetFeed.
/// When a user signs in, starts the UserService listener. When the user's
/// registered helmetIds change, pushes them into HelmetFeed.
class _UserHelmetBridge extends StatefulWidget {
  const _UserHelmetBridge();
  @override
  State<_UserHelmetBridge> createState() => _UserHelmetBridgeState();
}

class _UserHelmetBridgeState extends State<_UserHelmetBridge> {
  @override
  Widget build(BuildContext context) {
    // Start listening when user signs in.
    final uid = context.select<AuthService, String?>((a) => a.user?.uid);
    final userSvc = context.read<UserService>();
    if (uid != null) {
      userSvc.listen(uid);
    } else {
      userSvc.clear();
    }

    // Push registered IDs into the feed whenever they change.
    final ids = context.select<UserService, List<String>>((s) => s.helmetIds);
    context.read<HelmetFeed>().updateHelmetIds(ids);

    return const CommandCenterPage();
  }
}

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({super.key});
  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  String? _selectedId = 'HLX-0187';
  String _filter = 'all';
  String _tab = 'Live';

  void _openSettings() {
    final feed = context.read<HelmetFeed>();
    final auth = context.read<AuthService>();
    final userSvc = context.read<UserService>();
    showDialog(
      context: context,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: feed),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: userSvc),
        ],
        child: const SettingsDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.read<HelmetFeed>();
    final helmets = context.select<HelmetFeed, List<Helmet>>((f) => f.helmets);
    final selectedId = _selectedId;
    final selected = selectedId == null
        ? null
        : helmets.firstWhere(
            (h) => h.id == selectedId,
            orElse: () => Helmet.empty(),
          );
    final selectedSafe = selected is Helmet && selected.id.isNotEmpty ? selected : null;
    final sosCount = context.select<HelmetFeed, int>(
      (f) => f.helmets.where((h) => h.effectiveStatus == HelmetStatus.sos).length,
    );

    final isLoading = context.select<HelmetFeed, bool>((f) => f.loading);
    final streamError = context.select<HelmetFeed, String?>((f) => f.error);

    return Scaffold(
      body: Column(children: [
        CommandHeader(
          siteName: kSiteName,
          sosCount: sosCount,
          activeTab: _tab,
          onTabChange: (t) => setState(() => _tab = t),
          onOpenSettings: _openSettings,
        ),
        // Loading indicator while waiting for first Firestore snapshot
        if (isLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Color(0xFF1e293b),
            valueColor: AlwaysStoppedAnimation(Color(0xFF3b82f6)),
          ),
        // Error banner if Firestore stream fails
        if (streamError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x33ef4444),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(streamError,
                    style: const TextStyle(color: Color(0xFFef4444), fontSize: 12)),
              ),
              IconButton(
                onPressed: () {
                  // Re-trigger subscription to clear error
                  final ids = context.read<UserService>().helmetIds;
                  context.read<HelmetFeed>().updateHelmetIds([]);
                  context.read<HelmetFeed>().updateHelmetIds(ids);
                },
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFef4444)),
                tooltip: 'Retry',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ]),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildTab(feed, helmets, selectedSafe),
          ),
        ),
        Container(
          width: double.infinity,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.sidebar,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '© 2026 HELIX. All rights reserved.',
                style: TextStyle(color: AppColors.mutedFg, fontSize: 11),
              ),
              InkWell(
                onTap: () {
                  html.window.open('/ppl/', '_blank');
                },
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildTab(HelmetFeed feed, List<Helmet> helmets, Helmet? selected) {
    switch (_tab) {
      case 'Fleet':
        return FleetView(
          helmets: helmets,
          selectedId: _selectedId,
          selected: selected,
          onSelect: (id) => setState(() => _selectedId = id),
          filter: _filter,
          onFilterChange: (f) => setState(() => _filter = f),
          onClose: () => setState(() => _selectedId = null),
        );
      case 'Incidents':
        return IncidentsView(
          feed: feed,
          onSelect: (id) => setState(() {
            _selectedId = id;
            _tab = 'Live';
          }),
        );
      case 'Zones':
        return ZonesView(
          helmets: helmets,
          selectedId: _selectedId,
          onSelect: (id) => setState(() => _selectedId = id),
        );
      case 'Reports':
        return ReportsView(helmets: helmets, alerts: feed.alerts);
      case 'Live':
      default:
        return LiveView(
          feed: feed,
          helmets: helmets,
          selectedId: _selectedId,
          selected: selected,
          onSelect: (id) => setState(() => _selectedId = id),
          filter: _filter,
          onFilterChange: (f) => setState(() => _filter = f),
          onClose: () => setState(() => _selectedId = null),
        );
    }
  }
}
