import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_service.dart';
import '../theme/app_theme.dart';

/// Dialog that lets the user register new helmet IDs and remove existing ones.
class RegisterHelmetDialog extends StatefulWidget {
  const RegisterHelmetDialog({super.key});

  @override
  State<RegisterHelmetDialog> createState() => _RegisterHelmetDialogState();
}

class _RegisterHelmetDialogState extends State<RegisterHelmetDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _register() async {
    final id = _controller.text.trim().toUpperCase();
    if (id.isEmpty) {
      setState(() => _error = 'Enter a helmet ID.');
      return;
    }
    final svc = context.read<UserService>();
    if (svc.helmetIds.contains(id)) {
      setState(() => _error = '$id is already registered.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await svc.registerHelmet(id);
      _controller.clear();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Failed: $e';
        });
      }
    }
  }

  Future<void> _unregister(String id) async {
    final svc = context.read<UserService>();
    try {
      await svc.unregisterHelmet(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove $id: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.select<UserService, List<String>>((s) => s.helmetIds);

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.add_circle_outline,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Register Helmets',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
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
                'Add helmet IDs to your account. Only registered helmets appear on the dashboard.',
                style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
              ),
              const SizedBox(height: 16),

              // Input row
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 13),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. HLX-001',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.mutedFg),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.accent,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onSubmitted: (_) => _register(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _register,
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
                        : const Text('Add', style: TextStyle(fontSize: 13)),
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

              // Registered helmets list
              Text('REGISTERED (${ids.length})'.toUpperCase(),
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
                    child: Text('No helmets registered yet.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.mutedFg)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: ids.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
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
                          InkWell(
                            onTap: () => _unregister(id),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.remove_circle_outline,
                                  size: 14, color: AppColors.statusSos),
                            ),
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
