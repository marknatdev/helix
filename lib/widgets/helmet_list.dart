import 'package:flutter/material.dart';
import '../models/helmet.dart';
import '../theme/app_theme.dart';

class HelmetList extends StatelessWidget {
  final List<Helmet> helmets;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String filter; // 'all' or HelmetStatus.name
  final ValueChanged<String> onFilterChange;

  const HelmetList({
    super.key,
    required this.helmets,
    required this.selectedId,
    required this.onSelect,
    required this.filter,
    required this.onFilterChange,
  });

  @override
  Widget build(BuildContext context) {
    // Count by effective status (considering lastSeen for offline detection)
    final counts = {'all': helmets.length, 'sos': 0, 'active': 0, 'idle': 0, 'offline': 0};
    for (final h in helmets) {
      counts[h.effectiveStatus.name] = (counts[h.effectiveStatus.name] ?? 0) + 1;
    }

    final visible = filter == 'all'
        ? helmets
        : helmets.where((h) => h.effectiveStatus.name == filter).toList();
    final order = {
      HelmetStatus.sos: 0,
      HelmetStatus.active: 1,
      HelmetStatus.idle: 2,
      HelmetStatus.offline: 3,
    };
    final ordered = [...visible]
      ..sort((a, b) => order[a.effectiveStatus]!.compareTo(order[b.effectiveStatus]!));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Fleet roster',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Connected helmets · live telemetry',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.mutedFg)),
                ],
              ),
            ),
            Text('${visible.length} shown',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.mutedFg)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final f in const [
                ['all', 'All'],
                ['sos', 'SOS'],
                ['active', 'Active'],
                ['idle', 'Idle'],
                ['offline', 'Offline'],
              ])
                _FilterChip(
                  keyLabel: f[0],
                  label: f[1],
                  count: counts[f[0]] ?? 0,
                  selected: filter == f[0],
                  onTap: () => onFilterChange(f[0]),
                ),
            ],
          ),
        ),
        Expanded(
          child: ordered.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.construction_outlined,
                        size: 32,
                        color: AppColors.mutedFg.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Helmets Connected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Configure your telemetry feed in Settings (⚙️) or start the simulator to stream live data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedFg,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: ordered.length,
                  itemBuilder: (_, i) => _HelmetTile(
                    helmet: ordered[i],
                    selected: ordered[i].id == selectedId,
                    onTap: () => onSelect(ordered[i].id),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String keyLabel;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.keyLabel,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.border : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (keyLabel == 'sos') ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.statusSos,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? AppColors.foreground
                      : AppColors.mutedFg)),
          const SizedBox(width: 6),
          Text('$count',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppColors.mutedFg,
              )),
        ]),
      ),
    );
  }
}

class _HelmetTile extends StatelessWidget {
  final Helmet helmet;
  final bool selected;
  final VoidCallback onTap;
  const _HelmetTile({
    required this.helmet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(helmet.effectiveStatus);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.8)
                : Colors.transparent,
            border: const Border(
                bottom: BorderSide(color: AppColors.border)),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected)
                Container(width: 2, height: 58, color: AppColors.primary)
              else
                const SizedBox(width: 2, height: 58),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(helmet.initials,
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(helmet.worker,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                        _StatusPill(helmet.effectiveStatus),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(helmet.id,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppColors.mutedFg)),
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.mutedFg)),
                      Flexible(
                        child: Text(helmet.crew,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.mutedFg)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _MiniMetric(
                        icon: helmet.battery < 25
                            ? Icons.battery_alert
                            : Icons.battery_std,
                        text: '${helmet.battery.round()}%',
                        color: helmet.battery < 25
                            ? AppColors.statusSos
                            : AppColors.mutedFg,
                      ),
                      const SizedBox(width: 12),
                      _MiniMetric(
                        icon: helmet.effectiveStatus == HelmetStatus.offline
                            ? Icons.signal_cellular_off
                            : Icons.signal_cellular_alt,
                        text: helmet.effectiveStatus == HelmetStatus.offline
                            ? '—'
                            : '${helmet.signal.round()}%',
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.place_outlined,
                              size: 11, color: AppColors.mutedFg),
                          const SizedBox(width: 4),
                          Text(
                              '${helmet.lat.toStringAsFixed(4)}, ${helmet.lng.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mutedFg)),
                        ]),
                        Text(timeAgo(helmet.lastSeen),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedFg)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MiniMetric({required this.icon, required this.text, this.color});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color ?? AppColors.mutedFg),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: color ?? AppColors.mutedFg)),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  final HelmetStatus status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(statusLabel(status).toUpperCase(),
          style: TextStyle(
            color: c,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          )),
    );
  }
}
