import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../services/user_service.dart';
import '../state/helmet_feed.dart';
import '../theme/app_theme.dart';
import 'claim_helmet_dialog.dart';
import '../views/dev_config_page.dart';
import '../views/receiver_admin_page.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.read<HelmetFeed>();
    final auth = context.read<AuthService>();
    final connected = context.select<HelmetFeed, bool>((f) => f.connected);
    final helmetCount = context.select<HelmetFeed, int>((f) => f.helmets.length);
    final streamError = context.select<HelmetFeed, String?>((f) => f.error);
    final userEmail = context.select<AuthService, String?>(
      (a) => a.user?.email,
    );
    final isAdmin = context.select<UserService, bool>((s) => s.isAdmin);

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.settings_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                GestureDetector(
                  onDoubleTap: kDebugMode && isAdmin
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DevConfigPage(),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Command center settings',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
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
                'Manage live LoRaWAN telemetry feed.',
                style: TextStyle(fontSize: 11, color: AppColors.mutedFg),
              ),
              const SizedBox(height: 20),

              // Connection status
              const _SectionLabel('Data source'),
              const SizedBox(height: 6),
              _RowTile(
                icon: connected
                    ? Icons.cell_tower
                    : Icons.cloud_off_outlined,
                title: connected
                    ? 'Firestore connected'
                    : 'Waiting for data\u2026',
                subtitle: connected
                    ? '$helmetCount helmet(s) streaming via LoRaWAN'
                    : 'No helmet telemetry received yet.',
                trailing: Icon(
                  Icons.circle,
                  size: 10,
                  color: connected
                      ? AppColors.statusOk
                      : AppColors.statusOffline,
                ),
              ),
              if (streamError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.statusSos.withValues(alpha: 0.1),
                    border: Border.all(
                        color: AppColors.statusSos.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.statusSos, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(streamError,
                          style: const TextStyle(
                              color: AppColors.statusSos, fontSize: 11)),
                    ),
                  ]),
                ),
              ],
              const Divider(color: AppColors.border, height: 20),

              // Manage helmets
              const _SectionLabel('Helmets'),
              const SizedBox(height: 6),
              Builder(builder: (ctx) {
                final helmetIds =
                    ctx.select<UserService, List<String>>((s) => s.helmetIds);
                return _ActionTile(
                  icon: Icons.construction,
                  title: 'Manage claimed helmets',
                  subtitle: helmetIds.isEmpty
                      ? 'No helmets claimed — tap to add.'
                      : '${helmetIds.length} helmet(s): ${helmetIds.join(", ")}',
                  onTap: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => ChangeNotifierProvider.value(
                        value: ctx.read<UserService>(),
                        child: const ClaimHelmetDialog(),
                      ),
                    );
                  },
                );
              }),
              const Divider(color: AppColors.border, height: 20),

              // Admin: manage receivers — only visible to users with role == 'admin'.
              if (isAdmin)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel('Admin'),
                    const SizedBox(height: 6),
                    _ActionTile(
                      icon: Icons.router_outlined,
                      title: 'Manage receivers',
                      subtitle: 'Provision and revoke gateway credentials.',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReceiverAdminPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppColors.border, height: 20),
                  ],
                ),

              // Acknowledge all
              _ActionTile(
                icon: Icons.check_circle_outline,
                title: 'Acknowledge all alerts',
                subtitle: 'Mark every active incident as resolved.',
                onTap: () {
                  feed.acknowledgeAll();
                  _toast(context, 'All alerts acknowledged.');
                },
              ),

              const SizedBox(height: 18),
              const _SectionLabel('Session'),
              const SizedBox(height: 6),
              _ActionTile(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: userEmail ?? 'Signed in',
                destructive: true,
                onTap: () async {
                  final nav = Navigator.of(context);
                  await auth.signOut();
                  if (nav.mounted) nav.pop();
                },
              ),

              const SizedBox(height: 20),
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

  void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.popover,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedFg,
        ));
  }
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _RowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.mutedFg),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedFg)),
          ],
        ),
      ),
      trailing,
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  @override
  Widget build(BuildContext context) {
    final c = destructive ? AppColors.statusSos : AppColors.foreground;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mutedFg)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 16, color: AppColors.mutedFg),
        ]),
      ),
    );
  }
}
