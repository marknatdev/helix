import 'package:flutter/material.dart';

import '../state/helmet_feed.dart';
import '../widgets/triage_lanes.dart';

class IncidentsView extends StatelessWidget {
  final HelmetFeed feed;
  final ValueChanged<String> onSelect;
  const IncidentsView({super.key, required this.feed, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return TriageLanes(
      alerts: feed.alerts,
      onSelect: onSelect,
      onAcknowledge: feed.acknowledge,
    );
  }
}
