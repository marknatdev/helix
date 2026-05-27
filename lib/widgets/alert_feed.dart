import 'package:flutter/material.dart';
import '../models/helmet.dart';
import '../theme/app_theme.dart';
import '../utils/snackbars.dart';

class AlertFeed extends StatelessWidget {
  final List<AlertEvent> alerts;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onAcknowledge;

  const AlertFeed({
    super.key,
    required this.alerts,
    required this.onSelect,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final active = alerts.where((a) => !a.resolved).toList();
    final resolved = alerts.where((a) => a.resolved).take(3).toList();

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
            const Icon(Icons.verified_user_outlined,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Incident feed',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${active.length} active · ${resolved.length} resolved',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.mutedFg)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => showComingSoon(context),
              icon: const Icon(Icons.phone, size: 14),
              label: const Text('Dispatch',
                  style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusSos,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final a in active) _ActiveAlertTile(
                alert: a,
                onSelect: onSelect,
                onAcknowledge: onAcknowledge,
              ),
              if (resolved.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('RESOLVED',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedFg)),
                ),
              for (final a in resolved)
                Opacity(
                  opacity: 0.7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.statusOk),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.message,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                            Text('${a.worker} · ${timeAgo(a.ts)}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mutedFg)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ActiveAlertTile extends StatelessWidget {
  final AlertEvent alert;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onAcknowledge;
  const _ActiveAlertTile({
    required this.alert,
    required this.onSelect,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final color = alertKindColor(alert.kind);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(alertKindIcon(alert.kind), size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(alertKindLabel(alert.kind).toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2)),
                  ),
                  const Spacer(),
                  Text(timeAgo(alert.ts),
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.mutedFg)),
                ]),
                const SizedBox(height: 6),
                Text(alert.message,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(alert.helmetId,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.mutedFg)),
                  const Text(' · ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.mutedFg)),
                  Text(alert.worker,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.mutedFg)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _SmallBtn(
                    label: 'Locate',
                    onTap: () => onSelect(alert.helmetId),
                    filled: true,
                  ),
                  const SizedBox(width: 6),
                  _SmallBtn(
                    label: 'Acknowledge',
                    onTap: () => onAcknowledge(alert.id),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _SmallBtn(
      {required this.label, required this.onTap, this.filled = false});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          border: Border.all(
              color: filled ? AppColors.border : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: filled
                    ? AppColors.foreground
                    : AppColors.mutedFg)),
      ),
    );
  }
}
