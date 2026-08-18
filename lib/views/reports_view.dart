import 'package:flutter/material.dart';

import '../models/helmet.dart';
import '../theme/app_theme.dart';
import '../widgets/fleet_stats.dart';

class ReportsView extends StatelessWidget {
  final List<Helmet> helmets;
  final List<AlertEvent> alerts;
  const ReportsView({super.key, required this.helmets, required this.alerts});
  @override
  Widget build(BuildContext context) {
    final active = alerts.where((a) => !a.resolved).length;
    final resolved = alerts.where((a) => a.resolved).length;
    final onlineCount = helmets
        .where((h) => h.effectiveStatus != HelmetStatus.offline)
        .length;

    final byCrew = <String, int>{};
    for (final h in helmets) {
      byCrew.update(h.crew, (v) => v + 1, ifAbsent: () => 1);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FleetStats(helmets: helmets),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Incident summary',
            child: Row(children: [
              _InlineStat(label: 'Active', value: '$active'),
              _InlineStat(label: 'Resolved', value: '$resolved'),
              _InlineStat(label: 'Online', value: '$onlineCount'),
              _InlineStat(label: 'Total helmets', value: '${helmets.length}'),
            ]),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Crews',
            child: Column(
              children: byCrew.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(fontSize: 13))),
                          Text('${e.value} helmets',
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppColors.mutedFg)),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ReportCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  color: AppColors.mutedFg,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  const _InlineStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: AppColors.mutedFg)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
