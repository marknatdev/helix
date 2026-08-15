import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Dev config page — reached via the settings dialog (double-tap the title),
/// gated on both kDebugMode and UserService.isAdmin so it's neither present
/// in release builds nor reachable by a non-admin in a debug build.
/// Lets you set helmet GPS position, status, battery, and toggle keep-alive
/// for demo/test helmets like HLX-001 and HLX-002.
///
/// Writes directly to Firestore; allowed because firestore.rules lets any
/// owner of a helmetId write its /helmets/{helmetId} doc.
class DevConfigPage extends ConsumerStatefulWidget {
  const DevConfigPage({super.key});

  @override
  ConsumerState<DevConfigPage> createState() => _DevConfigPageState();
}

class _DevConfigPageState extends ConsumerState<DevConfigPage> {
  final _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _helmets = [];
  String? _selectedId;
  bool _loading = true;

  // Edit controllers
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  final _speedCtrl = TextEditingController();
  final _headingCtrl = TextEditingController();
  final _workerCtrl = TextEditingController();
  String _status = 'active';
  bool _keepAlive = false;
  Timer? _keepAliveTimer;
  bool _isWalking = false;
  Timer? _walkTimer;
  double _walkAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _loadHelmets();
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _walkTimer?.cancel();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _batteryCtrl.dispose();
    _speedCtrl.dispose();
    _headingCtrl.dispose();
    _workerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHelmets() async {
    setState(() => _loading = true);
    try {
      final userSvc = ref.read(userServiceProvider);
      final ids = userSvc.helmetIds;
      if (ids.isEmpty) {
        _helmets = [];
      } else {
        final snap = await _db
            .collection('helmets')
            .where(FieldPath.documentId, whereIn: ids)
            .get();
        final Map<String, Map<String, dynamic>> existing = {
          for (var doc in snap.docs) doc.id: {'id': doc.id, ...doc.data()}
        };
        final List<Map<String, dynamic>> list = [];
        for (final id in ids) {
          if (existing.containsKey(id)) {
            list.add(existing[id]!);
          } else {
            list.add({
              'id': id,
              'helmetId': id,
              'status': 'offline',
              'battery': 100.0,
              'lat': 37.7749,
              'lng': -122.4194,
              'speed': 0.0,
              'heading': 0.0,
              'worker': '',
            });
          }
        }
        _helmets = list;
        _helmets.sort((a, b) => (a['helmetId'] ?? '').compareTo(b['helmetId'] ?? ''));
      }
    } catch (e) {
      debugPrint('[DevConfig] Error loading helmets: $e');
    }
    setState(() => _loading = false);
  }

  void _selectHelmet(String id) {
    final h = _helmets.firstWhere((h) => h['id'] == id, orElse: () => {});
    if (h.isEmpty) return;
    setState(() {
      _selectedId = id;
      _latCtrl.text = (h['lat'] ?? 0).toString();
      _lngCtrl.text = (h['lng'] ?? 0).toString();
      _batteryCtrl.text = (h['battery'] ?? 0).toString();
      _speedCtrl.text = (h['speed'] ?? 0).toString();
      _headingCtrl.text = (h['heading'] ?? 0).toString();
      _workerCtrl.text = h['worker'] ?? '';
      _status = h['status'] ?? 'offline';
      _keepAlive = false;
      _isWalking = false;
    });
    _keepAliveTimer?.cancel();
    _walkTimer?.cancel();
  }

  Future<void> _saveConfig() async {
    if (_selectedId == null) return;

    try {
      final update = <String, dynamic>{
        'helmetId': _selectedId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final lat = double.tryParse(_latCtrl.text);
      final lng = double.tryParse(_lngCtrl.text);
      if (lat != null) update['lat'] = lat;
      if (lng != null) update['lng'] = lng;
      update['status'] = _status;
      final bat = double.tryParse(_batteryCtrl.text);
      if (bat != null) update['battery'] = bat;
      final spd = double.tryParse(_speedCtrl.text);
      if (spd != null) update['speed'] = spd;
      final hdg = double.tryParse(_headingCtrl.text);
      if (hdg != null) update['heading'] = hdg;
      update['worker'] = _workerCtrl.text;
      if (_keepAlive) update['lastSeen'] = FieldValue.serverTimestamp();

      await _db.collection('helmets').doc(_selectedId).set(
        update,
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $_selectedId updated'),
            backgroundColor: AppColors.popover,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _loadHelmets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _toggleKeepAlive(bool value) {
    setState(() => _keepAlive = value);
    _keepAliveTimer?.cancel();
    if (value && _selectedId != null) {
      // Ping lastSeen every 30 seconds to keep helmet "online"
      _pingLastSeen();
      _keepAliveTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _pingLastSeen(),
      );
    }
  }

  Future<void> _pingLastSeen() async {
    if (_selectedId == null) return;
    try {
      await _db.collection('helmets').doc(_selectedId).set({
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[DevConfig] Keep-alive ping for $_selectedId');
    } catch (e) {
      debugPrint('[DevConfig] Ping error: $e');
    }
  }

  void _toggleWalk(bool value) {
    setState(() => _isWalking = value);
    _walkTimer?.cancel();
    if (value && _selectedId != null) {
      _walkAngle = 0.0;
      _stepWalk();
      _walkTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _stepWalk(),
      );
    }
  }

  Future<void> _stepWalk() async {
    if (_selectedId == null) return;
    final lat = double.tryParse(_latCtrl.text) ?? 37.7749;
    final lng = double.tryParse(_lngCtrl.text) ?? -122.4194;

    // Advance walking angle randomly
    _walkAngle += (math.Random().nextDouble() - 0.5) * 0.5 + 0.2;
    // Step size about 8-10 meters (approx 0.00008 degrees)
    final nextLat = lat + 0.00008 * math.sin(_walkAngle);
    final nextLng = lng + 0.00008 * math.cos(_walkAngle);

    _latCtrl.text = nextLat.toStringAsFixed(14);
    _lngCtrl.text = nextLng.toStringAsFixed(14);

    try {
      final update = <String, dynamic>{
        'helmetId': _selectedId,
        'lat': nextLat,
        'lng': nextLng,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('helmets').doc(_selectedId).set(
        update,
        SetOptions(merge: true),
      );
      debugPrint('[DevConfig] Walk step for $_selectedId: $nextLat, $nextLng');
    } catch (e) {
      debugPrint('[DevConfig] Walk step error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        title: const Row(
          children: [
            Icon(Icons.developer_mode, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Dev Config',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            _SecretBadge(),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadHelmets,
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Helmet list
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border(
                        right: BorderSide(color: AppColors.border)),
                  ),
                  child: ListView.builder(
                    itemCount: _helmets.length,
                    itemBuilder: (_, i) {
                      final h = _helmets[i];
                      final id = h['helmetId'] ?? h['id'];
                      final isSelected = _selectedId == h['id'];
                      final status = h['status'] ?? 'offline';
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: status == 'active'
                              ? AppColors.statusOk
                              : status == 'sos'
                                  ? AppColors.statusSos
                                  : AppColors.statusOffline,
                        ),
                        title: Text(id,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.foreground,
                            )),
                        subtitle: Text(
                          status,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.mutedFg),
                        ),
                        onTap: () => _selectHelmet(h['id']),
                      );
                    },
                  ),
                ),
                // Editor
                Expanded(
                  child: _selectedId == null
                      ? const Center(
                          child: Text('Select a helmet to configure',
                              style: TextStyle(
                                  color: AppColors.mutedFg, fontSize: 13)),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildEditor(),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_selectedId ?? '',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
        const SizedBox(height: 20),

        // GPS
        const _Label('GPS POSITION'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('Latitude', _latCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _field('Longitude', _lngCtrl)),
        ]),
        const SizedBox(height: 16),

        // Status
        const _Label('STATUS'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'active', label: Text('Active')),
            ButtonSegment(value: 'idle', label: Text('Idle')),
            ButtonSegment(value: 'sos', label: Text('SOS')),
            ButtonSegment(value: 'offline', label: Text('Offline')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(AppColors.foreground),
          ),
        ),
        const SizedBox(height: 16),

        // Telemetry
        const _Label('TELEMETRY'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field('Battery %', _batteryCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _field('Speed (km/h)', _speedCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _field('Heading (°)', _headingCtrl)),
        ]),
        const SizedBox(height: 16),

        // Worker
        const _Label('WORKER'),
        const SizedBox(height: 8),
        _field('Worker name', _workerCtrl),
        const SizedBox(height: 16),

        // Keep alive
        const _Label('KEEP ALIVE'),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _keepAlive,
          onChanged: _toggleKeepAlive,
          title: const Text('Auto-ping lastSeen (every 30s)',
              style: TextStyle(fontSize: 13)),
          subtitle: const Text(
            'Keeps the helmet "online" in the dashboard by updating lastSeen periodically.',
            style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
          ),
          activeColor: AppColors.statusOk,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        ),
        const SizedBox(height: 16),

        // Simulate walk
        const _Label('SIMULATE GPS WALK'),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _isWalking,
          onChanged: _toggleWalk,
          title: const Text('Simulate walking path',
              style: TextStyle(fontSize: 13)),
          subtitle: const Text(
            'Periodically updates GPS coordinates in real-time to simulate a walking worker.',
            style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
          ),
          activeColor: AppColors.statusOk,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        ),
        const SizedBox(height: 24),

        // Save
        SizedBox(
          width: 200,
          child: ElevatedButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 11, color: AppColors.mutedFg),
        filled: true,
        fillColor: AppColors.sidebar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedFg,
        ));
  }
}

class _SecretBadge extends StatelessWidget {
  const _SecretBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.statusWarn.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.statusWarn.withValues(alpha: 0.5)),
      ),
      child: const Text('SECRET',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.statusWarn,
            letterSpacing: 1,
          )),
    );
  }
}
