import 'package:flutter/material.dart';

import '../models/helmet.dart';
import '../widgets/fleet_map.dart';

class ZonesView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FleetMap(
      helmets: helmets,
      selectedId: selectedId,
      onSelect: onSelect,
    );
  }
}
