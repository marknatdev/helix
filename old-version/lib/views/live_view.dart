import 'package:flutter/material.dart';

import '../models/helmet.dart';
import '../state/helmet_feed.dart';
import '../widgets/alert_feed.dart';
import '../widgets/fleet_map.dart';
import '../widgets/fleet_stats.dart';
import '../widgets/helmet_detail.dart';
import '../widgets/helmet_list.dart';

class LiveView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final wide = bc.maxWidth >= 1100;
      if (wide) {
        return Column(children: [
          FleetStats(helmets: helmets),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: HelmetList(
                    helmets: helmets,
                    selectedId: selectedId,
                    onSelect: onSelect,
                    filter: filter,
                    onFilterChange: onFilterChange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: FleetMap(
                    helmets: helmets,
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                      child: AlertFeed(
                        alerts: feed.alerts,
                        onSelect: onSelect,
                        onAcknowledge: feed.acknowledge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: HelmetDetail(
                        helmet: selected,
                        onClose: onClose,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ]);
      }
      return SingleChildScrollView(
        child: Column(children: [
          FleetStats(helmets: helmets),
          const SizedBox(height: 12),
          SizedBox(
            height: 420,
            child: FleetMap(
              helmets: helmets,
              selectedId: selectedId,
              onSelect: onSelect,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 480,
            child: HelmetList(
              helmets: helmets,
              selectedId: selectedId,
              onSelect: onSelect,
              filter: filter,
              onFilterChange: onFilterChange,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: AlertFeed(
              alerts: feed.alerts,
              onSelect: onSelect,
              onAcknowledge: feed.acknowledge,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 420,
            child: HelmetDetail(helmet: selected, onClose: onClose),
          ),
        ]),
      );
    });
  }
}
