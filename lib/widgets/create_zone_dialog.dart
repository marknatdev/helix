import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/helmet.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Dialog for creating a new geofence zone. Center coordinates default to
/// the fleet's current centroid (or the selected helmet, if any) as a
/// placeholder — there's no real site survey data yet, so this gives a
/// sane starting point that's still editable before saving.
class CreateZoneDialog extends ConsumerStatefulWidget {
  final List<Helmet> helmets;
  final Helmet? selected;
  const CreateZoneDialog({super.key, required this.helmets, this.selected});

  @override
  ConsumerState<CreateZoneDialog> createState() => _CreateZoneDialogState();
}

class _CreateZoneDialogState extends ConsumerState<CreateZoneDialog> {
  final _nameController = TextEditingController();
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  final _radiusController = TextEditingController(text: '50');
  String _kind = 'operational';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final center = _placeholderCenter();
    _latController = TextEditingController(text: center.$1.toStringAsFixed(6));
    _lngController = TextEditingController(text: center.$2.toStringAsFixed(6));
  }

  (double, double) _placeholderCenter() {
    if (widget.selected != null) {
      return (widget.selected!.lat, widget.selected!.lng);
    }
    if (widget.helmets.isEmpty) return (37.7841, -122.4074); // kSiteCenter fallback
    final lat = widget.helmets.map((h) => h.lat).reduce((a, b) => a + b) / widget.helmets.length;
    final lng = widget.helmets.map((h) => h.lng).reduce((a, b) => a + b) / widget.helmets.length;
    return (lat, lng);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = double.tryParse(_radiusController.text.trim());
    if (name.isEmpty || lat == null || lng == null || radius == null || radius <= 0) {
      setState(() => _error = 'Enter a name and valid coordinates/radius.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(zoneServiceProvider).createZone(
            name: name,
            kind: _kind,
            centerLat: lat,
            centerLng: lng,
            radiusM: radius,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.crop_free, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('New Zone',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.mutedFg,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'Coordinates default to the fleet\'s current position as a '
                'placeholder — adjust to the real site boundary before relying '
                'on this for containment alerts.',
                style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
              ),
              const SizedBox(height: 16),
              _field('Zone name', _nameController, hint: 'e.g. Tower 2 work area'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _kind,
                    dropdownColor: AppColors.popover,
                    style: TextStyle(fontSize: 13, color: AppColors.foreground),
                    decoration: _decoration(),
                    items: const [
                      DropdownMenuItem(value: 'operational', child: Text('Operational')),
                      DropdownMenuItem(value: 'restricted', child: Text('Restricted')),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? 'operational'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field('Radius (m)', _radiusController,
                      keyboardType: TextInputType.number),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _field('Center lat', _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true))),
                const SizedBox(width: 8),
                Expanded(
                    child: _field('Center lng', _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true))),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppColors.statusSos, fontSize: 11)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryFg))
                      : const Text('Create'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: AppColors.mutedFg),
        isDense: true,
        filled: true,
        fillColor: AppColors.accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.border),
        ),
      );

  Widget _field(String label, TextEditingController controller,
      {String? hint, TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: _decoration(hint: hint),
      ),
    ]);
  }
}
