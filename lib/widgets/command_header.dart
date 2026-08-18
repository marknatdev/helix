import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'live_clock.dart';

class CommandHeader extends StatelessWidget {
  final String siteName;
  final int sosCount;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddHelmet;
  const CommandHeader({
    super.key,
    required this.siteName,
    required this.sosCount,
    required this.onOpenSettings,
    required this.onAddHelmet,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Container(
      height: 56,
      decoration: BoxDecoration(
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
            child: Icon(Icons.construction,
                color: AppColors.primaryFg, size: 16),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
          const Spacer(),
          if (wide) ...[
            _Badge(
              icon: Icons.radio,
              iconColor: AppColors.statusOk,
              children: [
                Text('MQTT',
                    style: TextStyle(color: AppColors.mutedFg, fontSize: 11)),
                const SizedBox(width: 6),
                Text(siteName,
                    style: TextStyle(
                        color: AppColors.foreground, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 8),
            _SosBadge(count: sosCount),
            const SizedBox(width: 8),
            const LiveClock(),
          ],

          const SizedBox(width: 8),
          _AddHelmetButton(onTap: onAddHelmet, compact: !wide),
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

class _AddHelmetButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _AddHelmetButton({required this.onTap, required this.compact});
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        color: AppColors.mutedFg,
        tooltip: 'Add helmet',
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.accent,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 14, color: AppColors.foreground),
          SizedBox(width: 6),
          Text('Add helmet', style: TextStyle(fontSize: 12)),
        ]),
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
