import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/helmet.dart';
import '../theme/app_theme.dart';
import '../utils/snackbars.dart';

/// Default map center — the job site's approximate coordinates.
const LatLng kSiteCenter = LatLng(37.7841, -122.4074);

class FleetMap extends StatefulWidget {
  final List<Helmet> helmets;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const FleetMap({
    super.key,
    required this.helmets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends State<FleetMap> {
  final MapController _ctrl = MapController();
  String? _lastFlownId;

  @override
  void didUpdateWidget(covariant FleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.selectedId;
    if (id != null && id != _lastFlownId) {
      final idx = widget.helmets.indexWhere((h) => h.id == id);
      if (idx != -1) {
        final h = widget.helmets[idx];
        _ctrl.move(LatLng(h.lat, h.lng), 18);
        _lastFlownId = id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        widget.helmets.where((h) => h.effectiveStatus == HelmetStatus.active).length;
    final sosCount =
        widget.helmets.where((h) => h.effectiveStatus == HelmetStatus.sos).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        FlutterMap(
          mapController: _ctrl,
          options: const MapOptions(
            initialCenter: kSiteCenter,
            initialZoom: 17,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.helix.command_center',
              // Light theme uses the tiles as-is; the inversion filter below
              // exists to make OSM's light tiles fit the dark palette.
              tileBuilder: AppColors.isLight ? null : darkTileBuilder,
            ),
            CircleLayer(circles: [
              CircleMarker(
                point: kSiteCenter,
                radius: 110,
                useRadiusInMeter: true,
                color: AppColors.primary.withValues(alpha: 0.04),
                borderStrokeWidth: 1.2,
                borderColor: AppColors.primary.withValues(alpha: 0.7),
              ),
            ]),
            MarkerLayer(
              markers: [
                for (final h in widget.helmets)
                  Marker(
                    key: ValueKey(h.id),
                    point: LatLng(h.lat, h.lng),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => widget.onSelect(h.id),
                      child: _HelmetMarker(
                        helmet: h,
                        selected: h.id == widget.selectedId,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Top-left status pill
        Positioned(
          top: 12,
          left: 12,
          child: _HudPill(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _LivePing(),
              const SizedBox(width: 8),
              const Text('Live map', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text('· Pier 27 Site',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.mutedFg)),
            ]),
          ),
        ),
        // Top-right controls
        Positioned(
          top: 12,
          right: 12,
          child: _HudPill(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _HudIconBtn(
                icon: Icons.layers_outlined,
                label: 'Layers',
                onTap: () => showComingSoon(context),
              ),
              _HudIconBtn(
                icon: Icons.center_focus_strong,
                onTap: () => _ctrl.move(kSiteCenter, 17),
              ),
              _HudIconBtn(
                icon: Icons.fullscreen,
                onTap: () => showComingSoon(context),
              ),
            ]),
          ),
        ),
        // Bottom-left legend
        Positioned(
          bottom: 12,
          left: 12,
          child: _HudPill(
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _LegendDot(color: AppColors.statusOk, label: 'Active $activeCount'),
                _LegendDot(color: AppColors.statusWarn, label: 'Idle'),
                _LegendDot(color: AppColors.statusSos, label: 'SOS $sosCount'),
                _LegendDot(color: AppColors.statusOffline, label: 'Offline'),
              ],
            ),
          ),
        ),
        // Bottom-right coords
        Positioned(
          bottom: 12,
          right: 12,
          child: _HudPill(
            child: Text('37.7841°N · 122.4074°W',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.mutedFg)),
          ),
        ),
      ]),
    );
  }
}

/// Inverts OSM's light tiles to fit the dark palette. Shared with ZoneMap so
/// both maps render identically; skipped entirely under the light theme,
/// where the raw tiles already match.
Widget darkTileBuilder(BuildContext ctx, Widget tile, TileImage image) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      // invert + hue-rotate approximation w/ slight de-sat and dim
      -0.8, -0.1, -0.1, 0, 230,
      -0.1, -0.8, -0.1, 0, 230,
      -0.1, -0.1, -0.8, 0, 230,
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}

class _HelmetMarker extends StatefulWidget {
  final Helmet helmet;
  final bool selected;
  const _HelmetMarker({required this.helmet, required this.selected});

  @override
  State<_HelmetMarker> createState() => _HelmetMarkerState();
}

class _HelmetMarkerState extends State<_HelmetMarker>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _maybeStartPulse();
  }

  @override
  void didUpdateWidget(covariant _HelmetMarker old) {
    super.didUpdateWidget(old);
    final needsPulse = widget.helmet.effectiveStatus == HelmetStatus.sos;
    if (needsPulse && _pulse == null) {
      _maybeStartPulse();
    } else if (!needsPulse && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  void _maybeStartPulse() {
    if (widget.helmet.effectiveStatus != HelmetStatus.sos) return;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(widget.helmet.effectiveStatus);
    final isSos = widget.helmet.effectiveStatus == HelmetStatus.sos;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isSos && _pulse != null)
          AnimatedBuilder(
            animation: _pulse!,
            builder: (_, _) {
              final t = _pulse!.value;
              return Container(
                width: 14 + 24 * t,
                height: 14 + 24 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 1 - t), width: 2),
                ),
              );
            },
          ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.background, width: 2),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.7),
                  blurRadius: widget.selected ? 16 : 8,
                  spreadRadius: widget.selected ? 2 : 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _HudPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _HudPill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.popover.withValues(alpha: 0.85),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class _HudIconBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  const _HudIconBtn({required this.icon, this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.mutedFg),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(label!,
                style: TextStyle(
                    fontSize: 11, color: AppColors.mutedFg)),
          ],
        ]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.mutedFg)),
    ]);
  }
}

class _LivePing extends StatefulWidget {
  const _LivePing();
  @override
  State<_LivePing> createState() => _LivePingState();
}

class _LivePingState extends State<_LivePing>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Opacity(
            opacity: (1 - _c.value) * 0.6,
            child: Container(
              width: 12 * _c.value + 4,
              height: 12 * _c.value + 4,
              decoration: BoxDecoration(
                color: AppColors.statusOk,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.statusOk,
            shape: BoxShape.circle,
          ),
        ),
      ]),
    );
  }
}
