import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/helmet.dart';
import '../models/zone.dart';
import '../theme/app_theme.dart';
import 'fleet_map.dart';

Color _zoneColor(String kind) =>
    kind == 'restricted' ? AppColors.statusSos : AppColors.primary;

/// Map showing zone geofence circles alongside live helmet positions.
/// Used by ZonesView instead of the plain FleetMap.
class ZoneMap extends StatelessWidget {
  final List<Zone> zones;
  final List<Helmet> helmets;
  final String? selectedZoneId;
  final ValueChanged<String> onSelectZone;

  const ZoneMap({
    super.key,
    required this.zones,
    required this.helmets,
    required this.selectedZoneId,
    required this.onSelectZone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
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
          ),
          CircleLayer(circles: [
            for (final z in zones)
              CircleMarker(
                point: LatLng(z.centerLat, z.centerLng),
                radius: z.radiusM,
                useRadiusInMeter: true,
                color: _zoneColor(z.kind).withValues(
                    alpha: z.id == selectedZoneId ? 0.16 : 0.06),
                borderStrokeWidth: z.id == selectedZoneId ? 2.4 : 1.2,
                borderColor: _zoneColor(z.kind)
                    .withValues(alpha: z.id == selectedZoneId ? 0.95 : 0.6),
              ),
          ]),
          MarkerLayer(markers: [
            for (final z in zones)
              Marker(
                key: ValueKey('zone-${z.id}'),
                point: LatLng(z.centerLat, z.centerLng),
                width: 90,
                height: 22,
                child: GestureDetector(
                  onTap: () => onSelectZone(z.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.popover.withValues(alpha: 0.85),
                      border: Border.all(color: _zoneColor(z.kind)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(z.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: _zoneColor(z.kind))),
                  ),
                ),
              ),
          ]),
          MarkerLayer(markers: [
            for (final h in helmets)
              Marker(
                key: ValueKey('helmet-${h.id}'),
                point: LatLng(h.lat, h.lng),
                width: 12,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor(h.effectiveStatus),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}
