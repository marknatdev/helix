import 'package:flutter/material.dart';
import '../models/helmet.dart';
import '../theme/app_theme.dart';
import '../utils/snackbars.dart';

/// Three-lane triage board (SOS / Alerts / Resolved), replacing the flat
/// incident list on the Incidents screen.
class TriageLanes extends StatelessWidget {
  final List<AlertEvent> alerts;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onAcknowledge;

  const TriageLanes({
    super.key,
    required this.alerts,
    required this.onSelect,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final active = alerts.where((a) => !a.resolved).toList();
    final sos = active.where((a) => a.kind == AlertKind.sos).toList();
    final other = active.where((a) => a.kind != AlertKind.sos).toList();
    final resolved = alerts.where((a) => a.resolved).toList();

    return LayoutBuilder(builder: (ctx, bc) {
      final wide = bc.maxWidth >= 900;
      final lanes = [
        _Lane(
          title: 'SOS',
          icon: Icons.shield_outlined,
          accent: AppColors.statusSos,
          alerts: sos,
          onSelect: onSelect,
          onAcknowledge: onAcknowledge,
          emptyText: 'No active emergencies',
        ),
        _Lane(
          title: 'Alerts',
          icon: Icons.warning_amber_rounded,
          accent: AppColors.statusWarn,
          alerts: other,
          onSelect: onSelect,
          onAcknowledge: onAcknowledge,
          emptyText: 'No open alerts',
        ),
        _Lane(
          title: 'Resolved',
          icon: Icons.check_circle_outline,
          accent: AppColors.statusOk,
          alerts: resolved,
          onSelect: onSelect,
          onAcknowledge: null,
          emptyText: 'Nothing resolved yet',
        ),
      ];
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lanes.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: lanes[i]),
            ],
          ],
        );
      }
      return ListView(
        children: [
          for (final l in lanes) ...[
            SizedBox(height: 360, child: l),
            const SizedBox(height: 12),
          ],
        ],
      );
    });
  }
}

class _Lane extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<AlertEvent> alerts;
  final ValueChanged<String> onSelect;
  final ValueChanged<String>? onAcknowledge;
  final String emptyText;
  const _Lane({
    required this.title,
    required this.icon,
    required this.accent,
    required this.alerts,
    required this.onSelect,
    required this.onAcknowledge,
    required this.emptyText,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.08), Colors.transparent],
            ),
          ),
          child: Row(children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: accent)),
            const SizedBox(width: 6),
            Text('${alerts.length}',
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 11, color: AppColors.mutedFg)),
          ]),
        ),
        Expanded(
          child: alerts.isEmpty
              ? Center(
                  child: Text(emptyText,
                      style: TextStyle(fontSize: 12, color: AppColors.mutedFg)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: alerts.length,
                  itemBuilder: (_, i) => _TriageCard(
                    alert: alerts[i],
                    accent: accent,
                    onSelect: onSelect,
                    onAcknowledge: onAcknowledge,
                  ),
                ),
        ),
      ]),
    );
  }
}

class _TriageCard extends StatelessWidget {
  final AlertEvent alert;
  final Color accent;
  final ValueChanged<String> onSelect;
  final ValueChanged<String>? onAcknowledge;
  const _TriageCard({
    required this.alert,
    required this.accent,
    required this.onSelect,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = onAcknowledge == null;
    return Opacity(
      opacity: resolved ? 0.7 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.4),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(alertKindIcon(alert.kind), size: 12, color: accent),
            const SizedBox(width: 6),
            Text(alertKindLabel(alert.kind).toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: accent)),
            const Spacer(),
            Text(timeAgo(alert.ts),
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10, color: AppColors.mutedFg)),
          ]),
          const SizedBox(height: 6),
          Text(alert.message, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          Text('${alert.helmetId} · ${alert.worker}',
              style: TextStyle(fontSize: 10, color: AppColors.mutedFg)),
          const SizedBox(height: 8),
          Row(children: [
            _SmallBtn(label: 'Locate', filled: true, onTap: () => onSelect(alert.helmetId)),
            if (onAcknowledge != null) ...[
              const SizedBox(width: 6),
              _SmallBtn(label: 'Acknowledge', onTap: () => onAcknowledge!(alert.id)),
            ],
            const SizedBox(width: 6),
            _SmallBtn(label: 'Dispatch', onTap: () => showComingSoon(context)),
          ]),
        ]),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _SmallBtn({required this.label, required this.onTap, this.filled = false});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          border: Border.all(color: filled ? AppColors.border : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: filled ? AppColors.foreground : AppColors.mutedFg)),
      ),
    );
  }
}
