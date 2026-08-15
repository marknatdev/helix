import 'package:flutter/material.dart';

import '../models/helmet.dart';
import '../state/helmet_feed.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_feed.dart';
import '../widgets/fleet_map.dart';
import '../widgets/fleet_stats.dart';
import '../widgets/helmet_detail.dart';
import '../widgets/helmet_list.dart';

class LiveView extends StatefulWidget {
  final HelmetFeed feed;
  final List<Helmet> helmets;
  final String? selectedId;
  final Helmet? selected;
  final ValueChanged<String> onSelect;
  final String filter;
  final ValueChanged<String> onFilterChange;
  final VoidCallback onClose;
  const LiveView({
    super.key,
    required this.feed,
    required this.helmets,
    required this.selectedId,
    required this.selected,
    required this.onSelect,
    required this.filter,
    required this.onFilterChange,
    required this.onClose,
  });

  @override
  State<LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<LiveView> {
  bool _tickerExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final wide = bc.maxWidth >= 1100;
      if (wide) {
        final activeAlerts = widget.feed.alerts.where((a) => !a.resolved).length;
        return Stack(children: [
          Positioned.fill(
            child: FleetMap(
              helmets: widget.helmets,
              selectedId: widget.selectedId,
              onSelect: widget.onSelect,
            ),
          ),
          // Roster panel, docked top-left
          Positioned(
            top: 12,
            left: 12,
            bottom: _tickerExpanded ? 236 : 56,
            width: 300,
            child: HelmetList(
              helmets: widget.helmets,
              selectedId: widget.selectedId,
              onSelect: widget.onSelect,
              filter: widget.filter,
              onFilterChange: widget.onFilterChange,
            ),
          ),
          // Inspector panel, docked top-right
          Positioned(
            top: 12,
            right: 12,
            bottom: _tickerExpanded ? 236 : 56,
            width: 300,
            child: HelmetDetail(
              helmet: widget.selected,
              onClose: widget.onClose,
            ),
          ),
          // Bottom alert ticker
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            height: _tickerExpanded ? 220 : 40,
            child: _AlertTicker(
              expanded: _tickerExpanded,
              activeCount: activeAlerts,
              onToggle: () => setState(() => _tickerExpanded = !_tickerExpanded),
              feed: widget.feed,
              onSelect: widget.onSelect,
            ),
          ),
        ]);
      }
      return SingleChildScrollView(
        child: Column(children: [
          FleetStats(helmets: widget.helmets),
          const SizedBox(height: 12),
          SizedBox(
            height: 420,
            child: FleetMap(
              helmets: widget.helmets,
              selectedId: widget.selectedId,
              onSelect: widget.onSelect,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 480,
            child: HelmetList(
              helmets: widget.helmets,
              selectedId: widget.selectedId,
              onSelect: widget.onSelect,
              filter: widget.filter,
              onFilterChange: widget.onFilterChange,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: AlertFeed(
              alerts: widget.feed.alerts,
              onSelect: widget.onSelect,
              onAcknowledge: widget.feed.acknowledge,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 420,
            child: HelmetDetail(helmet: widget.selected, onClose: widget.onClose),
          ),
        ]),
      );
    });
  }
}

class _AlertTicker extends StatelessWidget {
  final bool expanded;
  final int activeCount;
  final VoidCallback onToggle;
  final HelmetFeed feed;
  final ValueChanged<String> onSelect;
  const _AlertTicker({
    required this.expanded,
    required this.activeCount,
    required this.onToggle,
    required this.feed,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final sos = activeCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.popover.withValues(alpha: 0.92),
        border: Border.all(
          color: sos ? AppColors.statusSos.withValues(alpha: 0.5) : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(Icons.campaign_outlined,
                  size: 15, color: sos ? AppColors.statusSos : AppColors.mutedFg),
              const SizedBox(width: 8),
              Text(
                sos ? '$activeCount active alert${activeCount == 1 ? '' : 's'}' : 'No active alerts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sos ? AppColors.statusSos : AppColors.mutedFg,
                ),
              ),
              const Spacer(),
              Icon(expanded ? Icons.expand_more : Icons.expand_less,
                  size: 16, color: AppColors.mutedFg),
            ]),
          ),
        ),
        if (expanded)
          Expanded(
            child: AlertFeed(
              alerts: feed.alerts,
              onSelect: onSelect,
              onAcknowledge: feed.acknowledge,
            ),
          ),
      ]),
    );
  }
}
