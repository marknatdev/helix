import 'package:flutter/material.dart';
import '../models/helmet.dart';
import '../theme/app_theme.dart';

enum _Tone { defaultT, ok, warn, sos }

class FleetStats extends StatelessWidget {
  final List<Helmet> helmets;
  const FleetStats({super.key, required this.helmets});

  @override
  Widget build(BuildContext context) {
    final total = helmets.length;
    int active = 0, idle = 0, sos = 0, offline = 0;
    double batSum = 0;
    int onlineCount = 0;
    for (final h in helmets) {
      switch (h.effectiveStatus) {
        case HelmetStatus.active:
          active++;
          break;
        case HelmetStatus.idle:
          idle++;
          break;
        case HelmetStatus.sos:
          sos++;
          break;
        case HelmetStatus.offline:
          offline++;
          break;
      }
      if (h.effectiveStatus != HelmetStatus.offline) {
        onlineCount++;
        batSum += h.battery;
      }
    }
    final avgBattery = onlineCount == 0 ? 0 : (batSum / onlineCount).round();

    final items = [
      _Stat(
        label: 'Active SOS',
        value: '$sos',
        sub: sos > 0 ? 'Immediate response required' : 'All clear',
        icon: Icons.shield_outlined,
        tone: sos > 0 ? _Tone.sos : _Tone.ok,
      ),
      _Stat(
        label: 'Helmets online',
        value: '${active + idle}',
        unit: '/ $total',
        sub: '$active active · $idle idle',
        icon: Icons.people_outline,
        tone: _Tone.ok,
      ),
      _Stat(
        label: 'Offline',
        value: '$offline',
        sub: '> 5 min no signal',
        icon: Icons.wifi_off,
        tone: offline > 0 ? _Tone.warn : _Tone.defaultT,
      ),
      _Stat(
        label: 'Avg. battery',
        value: '$avgBattery',
        unit: '%',
        sub: 'Across online fleet',
        icon: Icons.battery_std,
        tone: avgBattery < 40 ? _Tone.warn : _Tone.defaultT,
      ),
    ];

    return LayoutBuilder(builder: (ctx, bc) {
      int cols;
      if (bc.maxWidth >= 1000) {
        cols = 4;
      } else if (bc.maxWidth >= 600) {
        cols = 2;
      } else {
        cols = 1;
      }
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
        children: items,
      );
    });
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final IconData icon;
  final _Tone tone;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.sub,
    this.tone = _Tone.defaultT,
  });

  Color get _toneColor {
    switch (tone) {
      case _Tone.sos:
        return AppColors.statusSos;
      case _Tone.ok:
        return AppColors.statusOk;
      case _Tone.warn:
        return AppColors.statusWarn;
      case _Tone.defaultT:
        return AppColors.mutedFg;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: AppColors.mutedFg,
                      fontWeight: FontWeight.w500,
                    )),
                Icon(icon, size: 14, color: _toneColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  )),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit!,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.mutedFg)),
                ),
              ],
            ]),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub!,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.mutedFg)),
              ),
          ],
        ),
        if (tone == _Tone.sos)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 1, color: AppColors.statusSos),
          ),
      ]),
    );
  }
}
