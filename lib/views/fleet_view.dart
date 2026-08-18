import 'package:flutter/material.dart';

import '../models/helmet.dart';
import '../theme/app_theme.dart';
import '../widgets/fleet_table.dart';
import '../widgets/helmet_detail.dart';

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
    final table = Column(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Text('Fleet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${helmets.length} helmets',
              style: TextStyle(fontSize: 12, color: AppColors.mutedFg)),
        ]),
      ),
      Expanded(
        child: FleetTable(
          helmets: helmets,
          selectedId: selectedId,
          onSelect: onSelect,
        ),
      ),
    ]);

    return LayoutBuilder(builder: (ctx, bc) {
      final wide = bc.maxWidth >= 900;
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 7, child: table),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: HelmetDetail(helmet: selected, onClose: onClose),
          ),
        ]);
      }
      return table;
    });
  }
}
