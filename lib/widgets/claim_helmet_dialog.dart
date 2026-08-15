import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Dialog for claiming a helmet by its pairing code (see
/// spec-device-pairing-system.md) and releasing helmets already claimed.
/// Replaces the old free-text RegisterHelmetDialog — claiming now requires
/// server-side proof of ownership instead of typing an arbitrary ID.
class ClaimHelmetDialog extends ConsumerStatefulWidget {
  const ClaimHelmetDialog({super.key});

  @override
  ConsumerState<ClaimHelmetDialog> createState() => _ClaimHelmetDialogState();
}

class _ClaimHelmetDialogState extends ConsumerState<ClaimHelmetDialog> {
  final _idController = TextEditingController();
  final _codeController = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _claim() async {
    final id = _idController.text.trim().toUpperCase();
    final code = _codeController.text.trim();
    if (id.isEmpty || code.isEmpty) {
      setState(() => _error = 'Enter both the helmet ID and its pairing code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(userServiceProvider)
          .claimHelmet(helmetId: id, pairingCode: code);
      _idController.clear();
      _codeController.clear();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Claim failed: $e';
        });
      }
    }
  }

  Future<void> _release(String id) async {
    final svc = ref.read(userServiceProvider);
    try {
      await svc.unclaimHelmet(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release $id: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(userServiceProvider.select((s) => s.helmetIds));

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.qr_code_scanner,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Claim a Helmet',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.mutedFg,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                'Enter the helmet ID and the pairing code from its QR label. '
                'Only registered/claimed helmets appear on the dashboard.',
                style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _idController,
                style: const TextStyle(fontSize: 13),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Helmet ID, e.g. HLX-001',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.mutedFg),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.accent,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    style: const TextStyle(
                        fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Pairing code',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.mutedFg),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.accent,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: (_) => _claim(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _claim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryFg,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primaryFg))
                        : const Text('Claim', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ]),

              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.statusSos, fontSize: 11)),
              ],

              const SizedBox(height: 16),
              Text('CLAIMED (${ids.length})'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedFg,
                  )),
              const SizedBox(height: 8),

              if (ids.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('No helmets claimed yet.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.mutedFg)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: ids.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final id = ids[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          const Icon(Icons.construction,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(id,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _release(id),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.statusSos),
                            child: const Text('Release',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ]),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.foreground,
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
