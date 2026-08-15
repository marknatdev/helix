import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/helmet.dart';
import '../models/zone.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/create_zone_dialog.dart';
import '../widgets/zone_map.dart';

class ZonesView extends ConsumerStatefulWidget {
  final List<Helmet> helmets;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const ZonesView({
    super.key,
    required this.helmets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  ConsumerState<ZonesView> createState() => _ZonesViewState();
}

class _ZonesViewState extends ConsumerState<ZonesView> {
  String? _selectedZoneId;

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesStreamProvider);

    return zonesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text('Failed to load zones: $e',
            style: const TextStyle(color: AppColors.statusSos, fontSize: 12)),
      ),
      data: (zones) {
        final selectedZone = zones.where((z) => z.id == _selectedZoneId).firstOrNull;
        return LayoutBuilder(builder: (ctx, bc) {
          final wide = bc.maxWidth >= 1000;
          final list = _ZoneList(
            zones: zones,
            helmets: widget.helmets,
            selectedZoneId: _selectedZoneId,
            onSelect: (id) => setState(() => _selectedZoneId = id),
            onCreate: () => showDialog(
              context: context,
              builder: (_) => CreateZoneDialog(
                helmets: widget.helmets,
                selected: widget.helmets.where((h) => h.id == widget.selectedId).firstOrNull,
              ),
            ),
          );
          final map = ZoneMap(
            zones: zones,
            helmets: widget.helmets,
            selectedZoneId: _selectedZoneId,
            onSelectZone: (id) => setState(() => _selectedZoneId = id),
          );
          final detail = _ZoneDetail(
            zone: selectedZone,
            helmets: widget.helmets,
            onSelectHelmet: widget.onSelect,
            onClose: () => setState(() => _selectedZoneId = null),
          );

          if (wide) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: list),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: map),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: detail),
            ]);
          }
          return SingleChildScrollView(
            child: Column(children: [
              SizedBox(height: 380, child: map),
              const SizedBox(height: 12),
              SizedBox(height: 320, child: list),
              const SizedBox(height: 12),
              if (selectedZone != null) SizedBox(height: 320, child: detail),
            ]),
          );
        });
      },
    );
  }
}

class _ZoneList extends StatelessWidget {
  final List<Zone> zones;
  final List<Helmet> helmets;
  final String? selectedZoneId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  const _ZoneList({
    required this.zones,
    required this.helmets,
    required this.selectedZoneId,
    required this.onSelect,
    required this.onCreate,
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
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            const Expanded(
              child: Text('Zones', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            InkWell(
              onTap: onCreate,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 13, color: AppColors.foreground),
                  SizedBox(width: 4),
                  Text('New', style: TextStyle(fontSize: 11)),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: zones.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text('No zones yet. Create one to start geofencing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.mutedFg)),
                )
              : ListView.builder(
                  itemCount: zones.length,
                  itemBuilder: (_, i) {
                    final z = zones[i];
                    final inside = z.containment.values.where((v) => v).length;
                    return Material(
                      color: z.id == selectedZoneId
                          ? AppColors.accent.withValues(alpha: 0.8)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelect(z.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(children: [
                            Icon(
                              z.kind == 'restricted' ? Icons.block : Icons.crop_free,
                              size: 14,
                              color: z.kind == 'restricted'
                                  ? AppColors.statusSos
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(z.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(
                                      '${z.assignedHelmetIds.length} assigned · $inside inside · ${z.radiusM.round()}m radius',
                                      style: const TextStyle(
                                          fontSize: 10, color: AppColors.mutedFg)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ZoneDetail extends ConsumerWidget {
  final Zone? zone;
  final List<Helmet> helmets;
  final ValueChanged<String> onSelectHelmet;
  final VoidCallback onClose;
  const _ZoneDetail({
    required this.zone,
    required this.helmets,
    required this.onSelectHelmet,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final z = zone;
    if (z == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text('Select a zone to view assignments',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.mutedFg)),
      );
    }

    final ownedIds = ref.watch(userServiceProvider.select((s) => s.helmetIds));
    final unassignedOwned =
        ownedIds.where((id) => !z.assignedHelmetIds.contains(id)).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(z.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${z.kind} · ${z.radiusM.round()}m radius',
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedFg)),
              ]),
            ),
            IconButton(
              onPressed: () async {
                try {
                  await ref.read(zoneServiceProvider).deleteZone(z.id);
                  onClose();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                  }
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              color: AppColors.statusSos,
              tooltip: 'Delete zone',
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (unassignedOwned.isNotEmpty) ...[
                const Text('ASSIGN A HELMET YOU OWN',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in unassignedOwned)
                      ActionChip(
                        label: Text(id, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () async {
                          try {
                            await ref
                                .read(zoneServiceProvider)
                                .assignHelmet(zoneId: z.id, helmetId: id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Assign failed: $e')));
                            }
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const Text('ASSIGNED',
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
              const SizedBox(height: 6),
              if (z.assignedHelmetIds.isEmpty)
                const Text('No helmets assigned yet.',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedFg))
              else
                for (final id in z.assignedHelmetIds)
                  _AssignedRow(
                    helmetId: id,
                    helmet: helmets.where((h) => h.id == id).firstOrNull,
                    contained: z.containmentFor(id),
                    onLocate: () => onSelectHelmet(id),
                    onUnassign: ownedIds.contains(id)
                        ? () async {
                            try {
                              await ref
                                  .read(zoneServiceProvider)
                                  .unassignHelmet(zoneId: z.id, helmetId: id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Unassign failed: $e')));
                              }
                            }
                          }
                        : null,
                  ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _AssignedRow extends StatelessWidget {
  final String helmetId;
  final Helmet? helmet;
  final bool? contained;
  final VoidCallback onLocate;
  final VoidCallback? onUnassign;
  const _AssignedRow({
    required this.helmetId,
    required this.helmet,
    required this.contained,
    required this.onLocate,
    required this.onUnassign,
  });

  @override
  Widget build(BuildContext context) {
    final label = contained == null ? 'Unknown' : (contained! ? 'Inside' : 'Outside');
    final color = contained == null
        ? AppColors.mutedFg
        : (contained! ? AppColors.statusOk : AppColors.statusWarn);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: onLocate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(helmetId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                if (helmet != null)
                  Text(helmet!.worker,
                      style: const TextStyle(fontSize: 10, color: AppColors.mutedFg)),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ),
        if (onUnassign != null)
          IconButton(
            onPressed: onUnassign,
            icon: const Icon(Icons.close, size: 14),
            color: AppColors.mutedFg,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Unassign',
          ),
      ]),
    );
  }
}
