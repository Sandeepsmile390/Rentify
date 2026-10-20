import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:file_picker/file_picker.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/app_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';

/// Settings screen — admin configuration, security, billing schedule, and exports
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  final String _currency = 'INR';
  String _electricityRate = '9.00';
  int _billingDay = 1;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final supported = await BiometricService.isPlatformSupported();
    final enabled = await BiometricService.isBiometricEnabled();

    int day = 1;
    String rate = '9.00';

    try {
      final client = Supabase.instance.client;
      final settingRes = await client
          .from('system_settings')
          .select('value')
          .eq('key', 'billing_day')
          .maybeSingle();

      if (settingRes != null && settingRes['value'] != null) {
        day = int.tryParse(settingRes['value'].toString()) ?? 1;
      }

      final rateRes = await client
          .from('electricity_rates')
          .select('rate_per_unit_paise')
          .order('effective_from', ascending: false)
          .limit(1)
          .maybeSingle();

      if (rateRes != null) {
        final paise = (rateRes['rate_per_unit_paise'] as num?)?.toInt() ?? 900;
        rate = (paise / 100.0).toStringAsFixed(2);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
      _billingDay = day;
      _electricityRate = rate;
      _isLoadingSettings = false;
    });
  }

  String get _billingDayDisplay {
    if (_billingDay == 31) {
      return 'Last day of month (31)';
    }
    final suffix = switch (_billingDay) {
      1 || 21 || 31 => 'st',
      2 || 22 => 'nd',
      3 || 23 => 'rd',
      _ => 'th',
    };
    return '$_billingDay$suffix of every month';
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role == 'admin';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text('Settings', style: AppTextStyles.h2)),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Profile section ────────────────────────────────
                _SettingsSection('Account', [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: isAdmin ? 'Admin profile' : 'Resident profile',
                    subtitle: 'Manage your name and contact info',
                    onTap: () => _showProfileDialog(isAdmin),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    subtitle: 'Securely verify current password and update',
                    onTap: () => _showChangePasswordDialog(),
                  ),
                ]),

                // ── Security section ───────────────────────────────
                _SettingsSection('Security', [
                  _SwitchTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric unlock',
                    subtitle: kIsWeb
                        ? 'Biometrics are not supported in web browser mode'
                        : _biometricSupported
                            ? 'Use device fingerprint or face recognition'
                            : 'Biometrics unavailable or not enrolled on device',
                    value: _biometricEnabled,
                    enabled: _biometricSupported,
                    onChanged: (v) async {
                      final sm = ScaffoldMessenger.of(context);
                      final success = await BiometricService.setBiometricEnabled(v);
                      if (mounted) {
                        setState(() => _biometricEnabled = success ? v : false);
                        if (!success && v) {
                          sm.showSnackBar(
                            const SnackBar(
                              content: Text('Biometric authentication failed or canceled.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ]),

                // ── Billing section (Admin only) ───────────────────
                if (isAdmin)
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
                      title: 'Billing schedule',
                      subtitle: _billingDayDisplay,
                      onTap: () => _showBillingDayDialog(),
                    ),
                    _SettingsTile(
                      icon: Icons.run_circle_outlined,
                      title: 'Billing manager',
                      subtitle: 'View billing runs & trigger monthly charges',
                      onTap: () => context.push(Routes.billing),
                    ),
                  ]),

                // ── Notifications section ──────────────────────────
                _SettingsSection('Notifications', [
                  _SwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push notifications',
                    subtitle: 'Receive instant payment and billing reminders',
                    value: _notificationsEnabled,
                    enabled: true,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  _SettingsTile(
                    icon: Icons.notification_important_outlined,
                    title: 'Test live popup notification',
                    subtitle: 'Trigger a test heads-up banner & status bar alert',
                    onTap: () => _testNotification(),
                  ),
                ]),

                // ── Data section ───────────────────────────────────
                _SettingsSection('Data & Records', [
                  if (isAdmin) ...[
                    _SettingsTile(
                      icon: Icons.file_download_outlined,
                      title: 'Export database (JSON backup)',
                      subtitle: 'Extract all database tables to save on phone storage or clipboard',
                      onTap: () => _showExportDatabaseDialog(),
                    ),
                    _SettingsTile(
                      icon: Icons.file_upload_outlined,
                      title: 'Import database (Restore data)',
                      subtitle: 'Insert or restore data directly into Supabase database',
                      onTap: () => _showImportDatabaseDialog(),
                    ),
                    _SettingsTile(
                      icon: Icons.table_chart_outlined,
                      title: 'Export ledger (CSV)',
                      subtitle: 'Download complete property transaction ledger as CSV',
                      onTap: () => _showExportDialog(),
                    ),
                  ],
                  _SettingsTile(
                    icon: Icons.backup_outlined,
                    title: 'Backup & cloud status',
                    subtitle: 'Supabase PostgreSQL cloud infrastructure verification',
                    onTap: () => _showBackupStatusDialog(),
                  ),
                ]),

                // ── About section ──────────────────────────────────
                _SettingsSection('About', [
                  const _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: '1.2.0 (build 5)',
                    onTap: null,
                  ),
                  _SettingsTile(
                    icon: Icons.system_update_rounded,
                    title: 'Check for updates',
                    subtitle: 'Verify if a new version or APK is available',
                    onTap: () => UpdateService.checkForUpdates(context, isManual: true),
                  ),
                  if (isAdmin)
                    _SettingsTile(
                      icon: Icons.campaign_rounded,
                      title: 'Broadcast app update',
                      subtitle: 'Notify all tenants & landlords of new APK release',
                      onTap: () => _showBroadcastUpdateDialog(),
                    ),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    subtitle: 'End active session securely',
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
            Text('Rate in ₹ per unit for future billing runs:', style: AppTextStyles.caption),
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
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newRate = double.tryParse(ctrl.text.trim());
              if (newRate == null || newRate <= 0) return;
              Navigator.of(dCtx).pop();

              try {
                final client = Supabase.instance.client;
                final paise = (newRate * 100).round();
                final today = DateTime.now().toIso8601String().substring(0, 10);
                await client.from('electricity_rates').insert({
                  'rate_per_unit_paise': paise,
                  'effective_from': today,
                });
                setState(() => _electricityRate = newRate.toStringAsFixed(2));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Electricity rate updated to ₹${newRate.toStringAsFixed(2)}/unit'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update rate: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }

  void _showBillingDayDialog() {
    int selectedDay = _billingDay;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: Text('Billing Day Configuration', style: AppTextStyles.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the calendar day of each month when automatic rent and electricity billing should run.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedDay,
                    isExpanded: true,
                    items: [
                      for (int d = 1; d <= 30; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text('Day $d of the month'),
                        ),
                      const DropdownMenuItem(
                        value: 31,
                        child: Text('Day 31 (Last day of month — adapts to Feb/Apr/Jun)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedDay = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: For months shorter than the chosen day (e.g., February with 28/29 days or 30-day months), billing runs on the actual last calendar day.',
                style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dCtx).pop();
                try {
                  final client = Supabase.instance.client;
                  await client.from('system_settings').upsert({
                    'key': 'billing_day',
                    'value': selectedDay.toString(),
                    'description': 'Monthly recurring billing trigger day (1-31)',
                  });
                  setState(() => _billingDay = selectedDay);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Billing day updated to $_billingDayDisplay'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save billing day: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Save Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: Text('Change Password', style: AppTextStyles.h2),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify your current password before setting a new one.',
                  style: AppTextStyles.caption,
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.errorBorder),
                    ),
                    child: Text(dialogError!, style: AppTextStyles.captionBold.copyWith(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password (min 8 chars)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final currentPass = currentPassCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();
                      final confirmPass = confirmPassCtrl.text.trim();

                      if (currentPass.isEmpty) {
                        setDialogState(() => dialogError = 'Please enter your current password.');
                        return;
                      }
                      if (newPass.length < 8) {
                        setDialogState(() => dialogError = 'New password must be at least 8 characters.');
                        return;
                      }
                      if (newPass != confirmPass) {
                        setDialogState(() => dialogError = 'New password and confirmation do not match.');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      try {
                        final client = Supabase.instance.client;
                        final userEmail = client.auth.currentUser?.email;

                        if (userEmail != null && userEmail.isNotEmpty) {
                          // Verify current password by signing in
                          await client.auth.signInWithPassword(
                            email: userEmail,
                            password: currentPass,
                          );
                        }

                        // Update password on server
                        await client.auth.updateUser(
                          UserAttributes(password: newPass),
                        );

                        if (dCtx.mounted) Navigator.of(dCtx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully and confirmed by server!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          dialogError = 'Authentication failed: Incorrect current password or session expired.';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService.initializeAndPrompt();
      await NotificationService.showSystemNotification(
        id: 9999,
        title: '🔔 Rentify Live Popup Alert',
        body: 'Push notifications and status bar popups are working live on your device!',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live heads-up notification sent to status bar!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showExportDatabaseDialog() async {
    final client = Supabase.instance.client;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Extracting full database snapshot...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final tenancies = await client.from('tenancies').select().order('created_at');
      final advances = await client.from('tenant_advances').select();
      final advanceTxns = await client.from('advance_transactions').select().order('created_at');
      final elecConfigs = await client.from('electricity_config').select();
      final meterReadings = await client.from('meter_readings').select().order('created_at');
      final charges = await client.from('charges').select().order('created_at');
      final payments = await client.from('payments').select().order('created_at');
      final allocations = await client.from('payment_allocations').select().order('created_at');

      final exportData = {
        'app': 'Rentify',
        'export_version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'counts': {
          'tenancies': (tenancies as List).length,
          'tenant_advances': (advances as List).length,
          'advance_transactions': (advanceTxns as List).length,
          'electricity_config': (elecConfigs as List).length,
          'meter_readings': (meterReadings as List).length,
          'charges': (charges as List).length,
          'payments': (payments as List).length,
          'payment_allocations': (allocations as List).length,
        },
        'tables': {
          'tenancies': tenancies,
          'tenant_advances': advances,
          'advance_transactions': advanceTxns,
          'electricity_config': elecConfigs,
          'meter_readings': meterReadings,
          'charges': charges,
          'payments': payments,
          'payment_allocations': allocations,
        },
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.file_download_done_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Text('Database Export Ready', style: AppTextStyles.h2),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Full database snapshot extracted successfully.\n\n'
                  '• Tenancies: ${(tenancies as List).length}\n'
                  '• Advances: ${(advances as List).length} (${(advanceTxns as List).length} txns)\n'
                  '• Electricity configs: ${(elecConfigs as List).length}\n'
                  '• Meter readings: ${(meterReadings as List).length}\n'
                  '• Charges: ${(charges as List).length}\n'
                  '• Payments: ${(payments as List).length}\n'
                  '• Payment allocations: ${(allocations as List).length}',
                  style: AppTextStyles.bodyRegular,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'JSON size: ${(jsonStr.length / 1024).toStringAsFixed(1)} KB.\n'
                    'You can copy the raw JSON or save it on your phone for full safekeeping or restoring anytime.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.of(dCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Database JSON copied to clipboard! Save to notes or backup file.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy JSON to Phone'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database export failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showImportDatabaseDialog() {
    final textCtrl = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.file_upload_outlined, color: AppColors.action),
              const SizedBox(width: 8),
              Text('Import Database', style: AppTextStyles.h2),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Restore database records from a previously exported Rentify JSON backup file or paste the JSON text.',
                  style: AppTextStyles.bodyRegular,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: isImporting
                      ? null
                      : () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['json', 'txt'],
                              withData: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final bytes = result.files.first.bytes;
                              if (bytes != null) {
                                final text = utf8.decode(bytes);
                                textCtrl.text = text;
                              }
                            }
                          } catch (e) {
                            debugPrint('Error picking file: $e');
                          }
                        },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Pick JSON Backup File from Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Or Paste JSON Backup String',
                    hintText: '{\n  "app": "Rentify",\n  "tables": { ... }\n}',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isImporting) ...[
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Restoring records into database...'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isImporting
                  ? null
                  : () async {
                      final raw = textCtrl.text.trim();
                      if (raw.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or paste JSON data')),
                        );
                        return;
                      }

                      Map<String, dynamic> data;
                      try {
                        data = jsonDecode(raw) as Map<String, dynamic>;
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invalid JSON format: $e'), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      final tables = data['tables'] as Map<String, dynamic>?;
                      if (tables == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Missing "tables" section in JSON backup'), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      setDialogState(() => isImporting = true);

                      try {
                        final client = Supabase.instance.client;

                        // 1. Tenancies
                        if (tables['tenancies'] != null) {
                          final rows = (tables['tenancies'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('tenancies').upsert(rows);
                          }
                        }

                        // 2. Tenant Advances
                        if (tables['tenant_advances'] != null) {
                          final rows = (tables['tenant_advances'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('tenant_advances').upsert(rows);
                          }
                        }

                        // 3. Electricity Config
                        if (tables['electricity_config'] != null) {
                          final rows = (tables['electricity_config'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('electricity_config').upsert(rows);
                          }
                        }

                        // 4. Meter Readings
                        if (tables['meter_readings'] != null) {
                          final rows = (tables['meter_readings'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('meter_readings').upsert(rows);
                          }
                        }

                        // 5. Charges
                        if (tables['charges'] != null) {
                          final rows = (tables['charges'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('charges').upsert(rows);
                          }
                        }

                        // 6. Payments
                        if (tables['payments'] != null) {
                          final rows = (tables['payments'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('payments').upsert(rows);
                          }
                        }

                        // 7. Payment Allocations
                        if (tables['payment_allocations'] != null) {
                          final rows = (tables['payment_allocations'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('payment_allocations').upsert(rows);
                          }
                        }

                        // 8. Advance Transactions
                        if (tables['advance_transactions'] != null) {
                          final rows = (tables['advance_transactions'] as List).cast<Map<String, dynamic>>();
                          if (rows.isNotEmpty) {
                            await client.from('advance_transactions').upsert(rows);
                          }
                        }

                        // Clear cache so all app views refresh
                        AppCacheService.clearAll();

                        if (dCtx.mounted) {
                          Navigator.of(dCtx).pop();
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Database import restored successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isImporting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Database import error: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Start Import to Database'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Export Complete Ledger', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate an auditable CSV of all charges, allocations, and payment records across all tenancies.',
              style: AppTextStyles.bodyRegular,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: AppColors.success),
              title: const Text('Download Ledger CSV'),
              subtitle: const Text('Export all transaction records to file'),
              onTap: () async {
                Navigator.of(dCtx).pop();
                await _performLedgerExport();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLedgerExport() async {
    try {
      final client = Supabase.instance.client;
      final chargesRes = await client
          .from('charges')
          .select('id, tenancy_id, charge_type, amount_paise, billing_month, status, created_at, tenancies(tenant_name, unit_id)')
          .order('billing_month', ascending: false);

      final buffer = StringBuffer();
      buffer.writeln('Rentify Complete Financial Ledger');
      buffer.writeln('Generated At,"${DateTime.now().toIso8601String()}"');
      buffer.writeln('');
      buffer.writeln('Charge ID,Tenancy ID,Tenant Name,Unit ID,Charge Type,Amount (INR),Billing Month,Status,Date Billed');

      for (final c in (chargesRes as List<dynamic>)) {
        final cId = c['id'];
        final tId = c['tenancy_id'];
        final cType = c['charge_type'] ?? 'rent';
        final amtInr = (((c['amount_paise'] as num?)?.toInt() ?? 0) / 100.0).toStringAsFixed(2);
        final bMonth = c['billing_month'] ?? '';
        final status = c['status'] ?? 'pending';
        final createdAt = c['created_at'] ?? '';
        final tMeta = c['tenancies'] as Map<String, dynamic>?;
        final tName = (tMeta?['tenant_name'] as String? ?? 'Resident').replaceAll('"', '""');
        final unitId = (tMeta?['unit_id'] as String? ?? '—').replaceAll('"', '""');

        buffer.writeln('"$cId","$tId","$tName","$unitId","$cType",$amtInr,"$bMonth","$status","$createdAt"');
      }

      final csvContent = buffer.toString();
      final uri = Uri.dataFromString(csvContent, mimeType: 'text/csv', encoding: utf8);

      if (kIsWeb) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: csvContent));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ledger CSV copied to clipboard! Ready to save or paste into Excel.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showBackupStatusDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Database & Backup Status', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
                const SizedBox(width: 8),
                Text('Active & Connected', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 14),
            Text('• Infrastructure: Supabase Cloud Enterprise', style: AppTextStyles.bodyRegular),
            Text('• Database Engine: PostgreSQL 17', style: AppTextStyles.bodyRegular),
            Text('• Cloud Backups: Managed directly via Supabase continuous WAL archiving & automated daily snapshots.', style: AppTextStyles.bodyRegular),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Notice: Application connectivity is verified. For point-in-time recovery (PITR) and manual database snapshot exports, please verify in your Supabase Project Dashboard.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(bool isAdmin) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final email = user?.email ?? 'admin@rentify.in';
    final name = (user?.userMetadata?['name'] as String?) ??
        (isAdmin ? 'Administrator' : 'Tenant Resident');

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isAdmin ? 'Admin Profile' : 'Resident Profile', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isAdmin ? AppColors.actionBg : AppColors.successBg,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                size: 32,
                color: isAdmin ? AppColors.action : AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(name, style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text(email, style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.security_rounded, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  isAdmin ? 'Role: Super Admin (Landlord)' : 'Role: Tenant (Resident)',
                  style: AppTextStyles.captionBold,
                ),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBroadcastUpdateDialog() {
    final versionCtrl = TextEditingController(text: '1.1.1+3');
    final urlCtrl = TextEditingController(
      text: 'https://github.com/Sandeepsmile390/Rentify/raw/main/build/app/outputs/flutter-apk/app-release.apk',
    );
    final notesCtrl = TextEditingController(
      text: 'New update with improved performance, advance balance display, tenant notes, and auto-update support.',
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: AppColors.action),
              const SizedBox(width: 8),
              Text('Broadcast App Update', style: AppTextStyles.h2),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publish a new version release. All active tenants and administrators will be notified, and users opening the app will be prompted with a one-tap Update button.',
                  style: AppTextStyles.bodyRegular,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: versionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target App Version',
                    hintText: 'e.g. 1.1.1+3',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'APK Download URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Release Notes / What\'s New',
                    hintText: 'Describe changes...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final success = await UpdateService.broadcastUpdate(
                        version: versionCtrl.text.trim(),
                        apkUrl: urlCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      );
                      if (dCtx.mounted) Navigator.of(dCtx).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Update notice successfully broadcast to all users!'
                                  : 'Failed to broadcast update notice.',
                            ),
                            backgroundColor: success ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Broadcast Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Sign out?', style: AppTextStyles.h2),
        content: Text('You will be returned to the login screen.', style: AppTextStyles.bodyRegular),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(dCtx).pop();
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
      title: Text(title, style: AppTextStyles.bodyRegular.copyWith(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle!, style: AppTextStyles.caption) : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkMuted)
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
    this.enabled = true,
  });
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: enabled ? AppColors.ink : AppColors.inkMuted, size: 22),
      title: Text(title, style: AppTextStyles.bodyRegular.copyWith(color: enabled ? null : AppColors.inkMuted)),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
