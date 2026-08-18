import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/helmet_admin_service.dart';
import '../theme/app_theme.dart';

class _ProvisionedHelmet {
  final String helmetId;
  final String? label;
  final DateTime at;
  _ProvisionedHelmet(this.helmetId, this.label, this.at);
}

/// Admin-only screen for provisioning helmets and one-time-revealing their
/// pairing code. Mirrors ReceiverAdminPage's provision/show-once flow, but
/// has no persisted list — firestore.rules gives admins `isAdmin()` read on
/// the whole `receivers` collection, not `helmets` (only the claiming owner
/// can read a helmet doc), so there's nothing to stream. This screen only
/// remembers what it provisioned in the current session.
/// Reached from SettingsDialog only when UserService.isAdmin is true.
class HelmetAdminPage extends StatefulWidget {
  const HelmetAdminPage({super.key});

  @override
  State<HelmetAdminPage> createState() => _HelmetAdminPageState();
}

class _HelmetAdminPageState extends State<HelmetAdminPage> {
  final _service = HelmetAdminService();
  final List<_ProvisionedHelmet> _sessionHistory = [];

  Future<void> _openProvisionDialog() async {
    final idCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Provision new helmet'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: idCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Helmet ID, e.g. HLX-001'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: labelCtrl,
                decoration:
                    const InputDecoration(labelText: 'Label (optional)'),
              ),
              const SizedBox(height: 12),
              Text(
                'The pairing code is shown exactly once after provisioning. '
                'It cannot be retrieved again — only re-provisioning the same '
                'unclaimed helmet ID issues a fresh one.',
                style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Provision'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final helmetId = idCtrl.text.trim().toUpperCase();
    final label = labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim();

    try {
      final pairingCode = await _service.provisionHelmet(
        helmetId: helmetId,
        label: label,
      );
      if (!mounted) return;
      setState(() {
        _sessionHistory.insert(0, _ProvisionedHelmet(helmetId, label, DateTime.now()));
      });
      await _showPairingCodeOnce(helmetId, pairingCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Provisioning failed: $e')),
        );
      }
    }
  }

  Future<void> _showPairingCodeOnce(String helmetId, String pairingCode) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Helmet provisioned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HELMET ID',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: SelectableText(
                  helmetId,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: helmetId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Helmet ID copied.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 15),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ]),
            const SizedBox(height: 10),
            Text('PAIRING CODE — SHOWN ONCE',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
            const SizedBox(height: 2),
            SelectableText(
              pairingCode,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 14, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'The pairing code will not be shown again. Give it to whoever '
              'is claiming this helmet (Settings → Manage claimed helmets, '
              'or the "Add helmet" button). Helmet ID is not secret; it '
              'stays visible below.',
              style: TextStyle(fontSize: 11, color: AppColors.statusWarn),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pairingCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pairing code copied.')),
              );
            },
            child: const Text('Copy code'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        title: const Text('Helmets',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            onPressed: _openProvisionDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Provision new helmet',
          ),
        ],
      ),
      body: _sessionHistory.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.construction_outlined,
                        size: 32, color: AppColors.mutedFg),
                    const SizedBox(height: 12),
                    Text('No helmets provisioned this session.',
                        style: TextStyle(color: AppColors.mutedFg)),
                    const SizedBox(height: 4),
                    Text(
                      'Pairing codes can only be shown once, right after '
                      'provisioning — there\'s no list of past ones to browse.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openProvisionDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Provision a helmet'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _sessionHistory.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _HistoryTile(entry: _sessionHistory[i]),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _ProvisionedHelmet entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.construction, size: 18, color: AppColors.statusOk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(entry.helmetId,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${entry.label ?? 'no label'} · provisioned ${_timeAgo(entry.at)}',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.helmetId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Helmet ID copied.')),
              );
            },
            icon: const Icon(Icons.copy, size: 14),
            color: AppColors.mutedFg,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Copy helmet ID',
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return '${s}s ago';
    return '${(s / 60).floor()}m ago';
  }
}
