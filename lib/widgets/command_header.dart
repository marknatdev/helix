import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'live_clock.dart';

const List<String> kHelixTabs = ['Live', 'Fleet', 'Incidents', 'Zones', 'Reports'];

class CommandHeader extends StatelessWidget {
  final String siteName;
  final int sosCount;
  final String activeTab;
  final ValueChanged<String> onTabChange;
  final VoidCallback onOpenSettings;
  const CommandHeader({
    super.key,
    required this.siteName,
    required this.sosCount,
    required this.activeTab,
    required this.onTabChange,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.construction,
                color: AppColors.primaryFg, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('HELIX',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 2,
                    color: AppColors.foreground,
                  )),
              Text('COMMAND CENTER',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2.5,
                    color: AppColors.mutedFg,
                  )),
            ],
          ),
          if (wide) ...[
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: AppColors.border),
            const SizedBox(width: 8),
            for (final e in kHelixTabs)
              _NavItem(
                label: e,
                active: e == activeTab,
                onTap: () => onTabChange(e),
              ),
          ] else ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: onTabChange,
              icon: const Icon(Icons.menu, size: 20, color: AppColors.mutedFg),
              tooltip: 'Navigation',
              color: AppColors.popover,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              itemBuilder: (_) => kHelixTabs
                  .map((e) => PopupMenuItem(
                        value: e,
                        child: Row(children: [
                          if (e == activeTab)
                            Container(
                              width: 4,
                              height: 16,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            )
                          else
                            const SizedBox(width: 12),
                          Text(e,
                              style: TextStyle(
                                fontSize: 13,
                                color: e == activeTab
                                    ? AppColors.foreground
                                    : AppColors.mutedFg,
                              )),
                        ]),
                      ))
                  .toList(),
            ),
          ],
          const Spacer(),
          if (wide) ...[
            _Badge(
              icon: Icons.radio,
              iconColor: AppColors.statusOk,
              children: [
                const Text('MQTT',
                    style: TextStyle(color: AppColors.mutedFg, fontSize: 11)),
                const SizedBox(width: 6),
                Text(siteName,
                    style: const TextStyle(
                        color: AppColors.foreground, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 8),
            _SosBadge(count: sosCount),
            const SizedBox(width: 8),
            const LiveClock(),
          ],

          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            color: AppColors.mutedFg,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.label,
    required this.onTap,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: active
            ? BoxDecoration(
                color: AppColors.accent,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              color: active ? AppColors.foreground : AppColors.mutedFg,
            )),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  const _Badge(
      {required this.icon, required this.iconColor, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: iconColor),
        const SizedBox(width: 6),
        ...children,
      ]),
    );
  }
}

class _SosBadge extends StatefulWidget {
  final int count;
  const _SosBadge({required this.count});
  @override
  State<_SosBadge> createState() => _SosBadgeState();
}

class _SosBadgeState extends State<_SosBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sos = widget.count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: sos
            ? AppColors.statusSos.withValues(alpha: 0.12)
            : AppColors.card,
        border: Border.all(
            color: sos
                ? AppColors.statusSos.withValues(alpha: 0.6)
                : AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FadeTransition(
          opacity: sos
              ? Tween<double>(begin: 0.4, end: 1).animate(_ac)
              : const AlwaysStoppedAnimation(1),
          child: Icon(Icons.shield_outlined,
              size: 14,
              color: sos ? AppColors.statusSos : AppColors.mutedFg),
        ),
        const SizedBox(width: 6),
        Text(
          sos ? '${widget.count} ACTIVE SOS' : 'NO ACTIVE EMERGENCIES',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: sos ? AppColors.statusSos : AppColors.mutedFg,
          ),
        ),
      ]),
    );
  }
}
