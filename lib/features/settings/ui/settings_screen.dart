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
  String _currency = 'INR';
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
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change password',
              subtitle: 'Update your login password',
              onTap: () {},
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
              icon: Icons.calendar_month_rounded,
              title: 'Billing day',
              subtitle: '1st of every month',
              onTap: () {},
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
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.backup_outlined,
              title: 'Backup status',
              subtitle: 'Last backup: today at 02:00 AM',
              onTap: () {},
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
      builder: (_) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _electricityRate = ctrl.text);
              Navigator.pop(context);
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
      builder: (_) => AlertDialog(
        title: Text('Run billing?', style: AppTextStyles.h2),
        content: Text(
          'This will generate rent and electricity charges for all active tenancies for the current month. Existing charges will not be duplicated.',
          style: AppTextStyles.bodyRegular,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
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
      builder: (_) => AlertDialog(
        title: Text('Sign out?', style: AppTextStyles.h2),
        content: Text('You will be returned to the login screen.',
            style: AppTextStyles.bodyRegular),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
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
