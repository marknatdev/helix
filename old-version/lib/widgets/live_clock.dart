import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Self-contained clock widget that rebuilds only itself every second.
class LiveClock extends StatefulWidget {
  const LiveClock({super.key});
  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  static final _fmt = DateFormat('HH:mm:ss');
  late String _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = '${_fmt.format(DateTime.now().toUtc())} UTC';
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = '${_fmt.format(DateTime.now().toUtc())} UTC');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(_now,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppColors.mutedFg,
            fontSize: 11,
          )),
    );
  }
}
