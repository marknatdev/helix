import 'package:flutter/material.dart';
import '../models/helmet.dart';
import '../theme/app_theme.dart';
import '../utils/snackbars.dart';

class HelmetDetail extends StatelessWidget {
  final Helmet? helmet;
  final VoidCallback onClose;

  const HelmetDetail({super.key, required this.helmet, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final h = helmet;
    if (h == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.place_outlined,
                  size: 16, color: AppColors.mutedFg),
            ),
            const SizedBox(height: 10),
            const Text('Select a helmet to inspect',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              'Click a marker on the map or a row in the roster to see live vitals, location history, and open a comms channel.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
            ),
          ],
        ),
      );
    }

    final c = statusColor(h.effectiveStatus);
    final batTone = h.battery < 20
        ? AppColors.statusSos
        : h.battery < 40
            ? AppColors.statusWarn
            : null;
    final sigTone = (h.signal < 60 && h.effectiveStatus != HelmetStatus.offline)
        ? AppColors.statusWarn
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(h.initials,
                      style: TextStyle(
                          color: c,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(h.worker,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(statusLabel(h.effectiveStatus).toUpperCase(),
                              style: TextStyle(
                                  color: c,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text('${h.id} · ${h.role} · ${h.crew}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.mutedFg)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.mutedFg,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (h.effectiveStatus == HelmetStatus.sos)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.statusSos.withValues(alpha: 0.1),
                        border: Border.all(
                            color:
                                AppColors.statusSos.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.statusSos, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Emergency active · SOS ${h.sinceSos}s ago · impact ${h.impactG.toStringAsFixed(1)}g',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ]),
                    ),
                  // 3 metrics, 3 columns
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.6,
                    children: [
                      _Metric(
                        icon: Icons.battery_std,
                        label: 'Battery',
                        value: '${h.battery.round()}',
                        unit: '%',
                        color: batTone,
                      ),
                      _Metric(
                        icon: Icons.radio,
                        label: 'Signal',
                        value: h.effectiveStatus == HelmetStatus.offline
                            ? '—'
                            : '${h.signal.round()}',
                        unit: h.effectiveStatus == HelmetStatus.offline ? '' : '%',
                        color: sigTone,
                      ),
                      _Metric(
                        icon: Icons.speed,
                        label: 'Impact',
                        value: h.impactG.toStringAsFixed(1),
                        unit: 'g',
                        color: h.impactG > 4 ? AppColors.statusSos : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MiniPanel(
                    icon: Icons.place_outlined,
                    label: 'COORDINATES',
                    value:
                        '${h.lat.toStringAsFixed(5)}, ${h.lng.toStringAsFixed(5)}',
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _MiniPanel(
                        icon: Icons.explore_outlined,
                        label: 'HEADING',
                        value: '${h.heading.round()}°',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniPanel(
                        icon: Icons.speed,
                        label: 'SPEED',
                        value: '${h.speed.toStringAsFixed(1)} m/s',
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // Footer actions
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.volume_up_outlined,
                  label: 'Push-to-talk',
                  onTap: () => showComingSoon(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone,
                  label: 'Call supervisor',
                  onTap: () => showComingSoon(context),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: AppColors.mutedFg),
            const SizedBox(width: 4),
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.mutedFg,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color ?? AppColors.foreground)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit!,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.mutedFg)),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _MiniPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniPanel(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: AppColors.mutedFg),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.mutedFg,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.foreground)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.accent,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.foreground),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }
}
