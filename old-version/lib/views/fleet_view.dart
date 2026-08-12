import 'package:flutter/material.dart';

import '../models/helmet.dart';
import '../widgets/helmet_detail.dart';
import '../widgets/helmet_list.dart';

class FleetView extends StatelessWidget {
  final List<Helmet> helmets;
  final String? selectedId;
  final Helmet? selected;
  final ValueChanged<String> onSelect;
  final String filter;
  final ValueChanged<String> onFilterChange;
  final VoidCallback onClose;
  const FleetView({
    super.key,
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
      final wide = bc.maxWidth >= 900;
      if (wide) {
        return Row(children: [
          Expanded(
            flex: 5,
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
            flex: 4,
            child: HelmetDetail(helmet: selected, onClose: onClose),
          ),
        ]);
      }
      return Column(children: [
        Expanded(
          child: HelmetList(
            helmets: helmets,
            selectedId: selectedId,
            onSelect: onSelect,
            filter: filter,
            onFilterChange: onFilterChange,
          ),
        ),
      ]);
    });
  }
}
