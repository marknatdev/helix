import 'package:flutter/material.dart';

import '../state/helmet_feed.dart';
import '../widgets/alert_feed.dart';

class IncidentsView extends StatelessWidget {
  final HelmetFeed feed;
  final ValueChanged<String> onSelect;
  const IncidentsView({super.key, required this.feed, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AlertFeed(
          alerts: feed.alerts,
          onSelect: onSelect,
          onAcknowledge: feed.acknowledge,
        ),
      ),
    );
  }
}
