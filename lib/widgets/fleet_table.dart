import 'package:flutter/material.dart';
import '../models/helmet.dart';
import '../theme/app_theme.dart';

enum _SortField { id, worker, status, battery, signal, lastSeen }

/// Dense sortable table view of the fleet, replacing the card-list roster
/// on the Fleet screen.
class FleetTable extends StatefulWidget {
  final List<Helmet> helmets;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const FleetTable({
    super.key,
    required this.helmets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<FleetTable> createState() => _FleetTableState();
}

class _FleetTableState extends State<FleetTable> {
  _SortField _sortField = _SortField.status;
  bool _asc = true;

  void _toggleSort(_SortField f) {
    setState(() {
      if (_sortField == f) {
        _asc = !_asc;
      } else {
        _sortField = f;
        _asc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const statusOrder = {
      HelmetStatus.sos: 0,
      HelmetStatus.active: 1,
      HelmetStatus.idle: 2,
      HelmetStatus.offline: 3,
    };
    final rows = [...widget.helmets];
    int cmp(Helmet a, Helmet b) {
      switch (_sortField) {
        case _SortField.id:
          return a.id.compareTo(b.id);
        case _SortField.worker:
          return a.worker.compareTo(b.worker);
        case _SortField.status:
          return statusOrder[a.effectiveStatus]!.compareTo(statusOrder[b.effectiveStatus]!);
        case _SortField.battery:
          return a.battery.compareTo(b.battery);
        case _SortField.signal:
          return a.signal.compareTo(b.signal);
        case _SortField.lastSeen:
          return a.lastSeen.compareTo(b.lastSeen);
      }
    }

    rows.sort((a, b) => _asc ? cmp(a, b) : cmp(b, a));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('No helmets connected.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedFg)),
            )
          : Column(children: [
              _HeaderRow(sortField: _sortField, asc: _asc, onSort: _toggleSort),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _FleetRow(
                    helmet: rows[i],
                    selected: rows[i].id == widget.selectedId,
                    striped: i.isOdd,
                    onTap: () => widget.onSelect(rows[i].id),
                  ),
                ),
              ),
            ]),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final _SortField sortField;
  final bool asc;
  final ValueChanged<_SortField> onSort;
  const _HeaderRow({required this.sortField, required this.asc, required this.onSort});

  @override
  Widget build(BuildContext context) {
    Widget col(String label, _SortField f, int flex) {
      final active = sortField == f;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => onSort(f),
          child: Row(children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.foreground : AppColors.mutedFg,
                )),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(asc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 10, color: AppColors.mutedFg),
            ],
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        col('Status', _SortField.status, 2),
        col('Helmet', _SortField.id, 3),
        col('Worker', _SortField.worker, 3),
        col('Battery', _SortField.battery, 2),
        col('Signal', _SortField.signal, 2),
        col('Last seen', _SortField.lastSeen, 2),
      ]),
    );
  }
}

class _FleetRow extends StatelessWidget {
  final Helmet helmet;
  final bool selected;
  final bool striped;
  final VoidCallback onTap;
  const _FleetRow({
    required this.helmet,
    required this.selected,
    required this.striped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(helmet.effectiveStatus);
    final batTone = helmet.battery >= 0 && helmet.battery < 25 ? AppColors.statusSos : null;
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.8)
          : striped
              ? AppColors.background.withValues(alpha: 0.25)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusLabel(helmet.effectiveStatus),
                    style: TextStyle(fontSize: 12, color: color)),
              ]),
            ),
            Expanded(
              flex: 3,
              child: Text(helmet.id,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            Expanded(
              flex: 3,
              child: Text(helmet.worker,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                helmet.battery >= 0 ? '${helmet.battery.round()}%' : '—',
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: batTone),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                helmet.signal > 0 ? '${helmet.signal.round()}%' : '—',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(timeAgo(helmet.lastSeen),
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedFg)),
            ),
          ]),
        ),
      ),
    );
  }
}
