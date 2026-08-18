import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/receiver.dart';
import '../services/receiver_service.dart';
import '../theme/app_theme.dart';

/// Admin-only screen (see firestore.rules receivers/{receiverId}: allow read
/// if isAdmin()) for provisioning and revoking Receiver gateway credentials.
/// Reached from SettingsDialog only when UserService.isAdmin is true.
class ReceiverAdminPage extends StatefulWidget {
  const ReceiverAdminPage({super.key});

  @override
  State<ReceiverAdminPage> createState() => _ReceiverAdminPageState();
}

class _ReceiverAdminPageState extends State<ReceiverAdminPage> {
  final _service = ReceiverService();

  Future<void> _openProvisionDialog() async {
    final hardwareCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Provision new receiver'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: hardwareCtrl,
                decoration: const InputDecoration(labelText: 'Hardware ID'),
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
                'The credential is shown exactly once after provisioning. '
                'Copy it into firmware/receiver/config.h before closing this dialog — '
                'it cannot be retrieved again, only rotated.',
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

    try {
      final (receiverId, credential) = await _service.provisionReceiver(
        hardwareId: hardwareCtrl.text.trim(),
        label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
      );
      if (mounted) await _showCredentialOnce(receiverId, credential);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Provisioning failed: $e')),
        );
      }
    }
  }

  Future<void> _showCredentialOnce(String receiverId, String credential) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Receiver provisioned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECEIVER ID',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: SelectableText(
                  receiverId,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receiverId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receiver ID copied.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 15),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ]),
            const SizedBox(height: 10),
            Text('CREDENTIAL — SHOWN ONCE',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedFg)),
            const SizedBox(height: 2),
            SelectableText(
              credential,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 14, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'The credential will not be shown again — copy it into the '
              'receiver\'s firmware/receiver/config.h (or the simulator\'s '
              'config) now. Receiver ID is not secret; it stays visible on '
              'this receiver\'s card below.',
              style: TextStyle(fontSize: 11, color: AppColors.statusWarn),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: credential));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credential copied to clipboard.')),
              );
            },
            child: const Text('Copy credential'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevoke(Receiver r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Revoke receiver?'),
        content: Text(
          'This immediately invalidates ${r.label}\'s credential. '
          'There is no grace period — the device stops authenticating right away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusSos),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _service.revokeReceiver(r.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoke failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        title: const Text('Receivers',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            onPressed: _openProvisionDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Provision new receiver',
          ),
        ],
      ),
      body: StreamBuilder<List<Receiver>>(
        stream: _service.receiversStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: AppColors.statusSos)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final receivers = snapshot.data!;
          if (receivers.isEmpty) {
            return Center(
              child: Text('No receivers provisioned yet.',
                  style: TextStyle(color: AppColors.mutedFg)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: receivers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ReceiverTile(
              receiver: receivers[i],
              onRevoke: () => _confirmRevoke(receivers[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ReceiverTile extends StatelessWidget {
  final Receiver receiver;
  final VoidCallback onRevoke;
  const _ReceiverTile({required this.receiver, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final active = receiver.state == ReceiverState.active;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.router,
              size: 18, color: active ? AppColors.statusOk : AppColors.mutedFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receiver.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'hw: ${receiver.hardwareId} · ${receiverStateLabel(receiver.state)}',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(
                    child: Text(
                      'id: ${receiver.id}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10, color: AppColors.mutedFg),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: receiver.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receiver ID copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 12),
                    color: AppColors.mutedFg,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  ),
                ]),
              ],
            ),
          ),
          if (active)
            TextButton(
              onPressed: onRevoke,
              style: TextButton.styleFrom(foregroundColor: AppColors.statusSos),
              child: const Text('Revoke'),
            ),
        ],
      ),
    );
  }
}
