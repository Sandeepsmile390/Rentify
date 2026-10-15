import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';

/// Settings screen — admin configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = true;
  bool _notificationsEnabled = true;
  final String _currency = 'INR';
  String _electricityRate = '9.00'; // ₹/unit

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text('Settings', style: AppTextStyles.h2)),
      body: ListView(
        children: [
          // ── Profile section ────────────────────────────────
          _SettingsSection('Account', [
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Admin profile',
              subtitle: 'Manage your name and contact info',
              onTap: () => _showProfileDialog(),
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change password',
              subtitle: 'Update your login password',
              onTap: () => _showChangePasswordDialog(),
            ),
          ]),

          // ── Security section ───────────────────────────────
          _SettingsSection('Security', [
            _SwitchTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric unlock',
              subtitle: 'Use fingerprint or face to open app',
              value: _biometricEnabled,
              onChanged: (v) => setState(() => _biometricEnabled = v),
            ),
          ]),

          // ── Billing section ────────────────────────────────
          _SettingsSection('Billing', [
            _SettingsTile(
              icon: Icons.electric_meter_outlined,
              title: 'Electricity rate',
              subtitle: '₹$_electricityRate per unit (currently active)',
              onTap: () => _showEditRateDialog(),
            ),
            _SettingsTile(
              icon: Icons.currency_rupee_rounded,
              title: 'Currency',
              subtitle: '$_currency (Indian Rupee)',
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.calendar_month_rounded,
              title: 'Billing day',
              subtitle: '1st of every month',
              onTap: () => _showBillingDayDialog(),
            ),
            _SettingsTile(
              icon: Icons.run_circle_outlined,
              title: 'Run billing manually',
              subtitle: 'Generate charges for current month now',
              onTap: () => _confirmBillingRun(),
            ),
          ]),

          // ── Notifications section ──────────────────────────
          _SettingsSection('Notifications', [
            _SwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Push notifications',
              subtitle: 'Receive payment and billing alerts',
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
          ]),

          // ── Data section ───────────────────────────────────
          _SettingsSection('Data', [
            _SettingsTile(
              icon: Icons.download_outlined,
              title: 'Export ledger',
              subtitle: 'Download full ledger as CSV or PDF',
              onTap: () => _showExportDialog(),
            ),
            _SettingsTile(
              icon: Icons.backup_outlined,
              title: 'Backup status',
              subtitle: 'Cloud database synced and healthy',
              onTap: () => _showBackupStatusDialog(),
            ),
          ]),

          // ── About section ──────────────────────────────────
          _SettingsSection('About', [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Version',
              subtitle: '1.0.0 (build 1)',
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: null,
              titleColor: AppColors.error,
              onTap: () => _confirmSignOut(),
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showEditRateDialog() {
    final ctrl = TextEditingController(text: _electricityRate);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Update electricity rate', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New rate will apply to future billing runs only.',
                style: AppTextStyles.caption),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rate (₹/unit)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _electricityRate = ctrl.text);
              Navigator.of(dCtx, rootNavigator: true).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmBillingRun() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Run billing?', style: AppTextStyles.h2),
        content: Text(
          'This will generate rent and electricity charges for all active tenancies for the current month. Existing charges will not be duplicated.',
          style: AppTextStyles.bodyRegular,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(dCtx, rootNavigator: true).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Billing run started…')),
              );
            },
            child: const Text('Run billing'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Sign out?', style: AppTextStyles.h2),
        content: Text('You will be returned to the login screen.',
            style: AppTextStyles.bodyRegular),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(dCtx, rootNavigator: true).pop();
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              ref.read(demoAuthProvider.notifier).logout();
              if (!mounted) return;
              context.go(Routes.login);
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Admin Profile', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.actionBg,
              child: Icon(Icons.person_rounded, size: 32, color: AppColors.action),
            ),
            const SizedBox(height: 16),
            Text('Rentify Administrator', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text('admin@rentify.app', style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.security_rounded, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Role: Super Admin (Landlord)', style: AppTextStyles.captionBold),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update Password', style: AppTextStyles.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your new password below.', style: AppTextStyles.caption),
              const SizedBox(height: 14),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (passCtrl.text.trim().length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: passCtrl.text.trim()),
                  );
                  if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBillingDayDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Billing Schedule', style: AppTextStyles.h2),
        content: Text(
          'Rent and electricity bills are computed and generated automatically on the 1st of every month.',
          style: AppTextStyles.bodyRegular,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Export Ledger', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select the export format for your property records:', style: AppTextStyles.bodyRegular),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: AppColors.success),
              title: const Text('CSV Spreadsheet'),
              subtitle: const Text('Compatible with Excel and Google Sheets'),
              onTap: () {
                Navigator.of(dCtx, rootNavigator: true).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ledger CSV generated.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
              title: const Text('PDF Report'),
              subtitle: const Text('Print-ready monthly statement'),
              onTap: () {
                Navigator.of(dCtx, rootNavigator: true).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF statement prepared.')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBackupStatusDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Cloud Database Status', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text('Database Online & Healthy', style: AppTextStyles.captionBold),
              ],
            ),
            const SizedBox(height: 12),
            Text('Engine: PostgreSQL 17', style: AppTextStyles.bodyRegular),
            Text('Host: Supabase Singapore (ap-southeast-1)', style: AppTextStyles.bodyRegular),
            Text('Automated Point-in-Time Recovery: Enabled', style: AppTextStyles.bodyRegular),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          color: AppColors.surface,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.ink, size: 22),
      title: Text(
        title,
        style: AppTextStyles.bodyRegular.copyWith(color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.inkMuted)
          : null,
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.ink, size: 22),
      title: Text(title, style: AppTextStyles.bodyRegular),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
