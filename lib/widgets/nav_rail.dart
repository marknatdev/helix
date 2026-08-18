import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavRailItem {
  final String label;
  final IconData icon;
  const NavRailItem(this.label, this.icon);
}

const List<NavRailItem> kHelixNavItems = [
  NavRailItem('Live', Icons.map_outlined),
  NavRailItem('Fleet', Icons.table_rows_outlined),
  NavRailItem('Incidents', Icons.warning_amber_rounded),
  NavRailItem('Zones', Icons.crop_free),
  NavRailItem('Reports', Icons.bar_chart_outlined),
];

/// Left icon rail navigation, replacing the old top tab bar.
class NavRail extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChange;
  const NavRail({super.key, required this.activeTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (final item in kHelixNavItems)
            _RailButton(
              item: item,
              active: item.label == activeTab,
              onTap: () => onTabChange(item.label),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final NavRailItem item;
  final bool active;
  final VoidCallback onTap;
  const _RailButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.accent : Colors.transparent,
              border: Border.all(color: active ? AppColors.border : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: active ? AppColors.primary : AppColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }
}
