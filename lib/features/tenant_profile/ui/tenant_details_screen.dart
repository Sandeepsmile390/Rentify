import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/providers/auth_provider.dart';

/// Read-only Details tab for tenants to inspect all tenancy and lease terms recorded by the landlord.
class TenantDetailsScreen extends ConsumerStatefulWidget {
  const TenantDetailsScreen({super.key});

  @override
  ConsumerState<TenantDetailsScreen> createState() => _TenantDetailsScreenState();
}

class _TenantDetailsScreenState extends ConsumerState<TenantDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _tenancyData;
  int _advanceBalancePaise = 0;
  int _rentRatePaise = 0;
  int _electricityRatePaise = 900;
  String _electricityMode = 'metered';
  double _initialMeterReading = 0.0;
  int _fixedElecAmountPaise = 0;
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Check biometric preference
      final supported = await BiometricService.isPlatformSupported();
      final enabled = await BiometricService.isBiometricEnabled();

      // Fetch tenancy for this tenant
      final tenRes = await client
          .from('tenancies')
          .select('*')
          .or('profile_id.eq.${user.id},mobile.eq.${user.phone ?? ""}')
          .order('created_at', ascending: false)
          .limit(1);

      Map<String, dynamic>? tenancy;
      if (tenRes.isNotEmpty) {
        tenancy = Map<String, dynamic>.from(tenRes.first as Map);
      } else {
        // Fallback: search by mobile digits if email is mobile@tenant.rentify.app
        final email = user.email ?? '';
        final digits = email.split('@').first.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10) {
          final tenByMobile = await client
              .from('tenancies')
              .select('*')
              .ilike('mobile', '%$digits%')
              .limit(1);
          if (tenByMobile.isNotEmpty) {
            tenancy = Map<String, dynamic>.from(tenByMobile.first as Map);
          }
        }
      }

      int advance = 0;
      int rentRate = 0;
      int elecRate = 900;
      String elecMode = 'metered';
      double initReading = 0.0;
      int fixedAmt = 0;

      if (tenancy != null) {
        final tId = tenancy['id'] as String;

        // 1. Fetch advance balance
        try {
          final advRes = await client
              .from('tenant_advances')
              .select('id')
              .eq('tenancy_id', tId)
              .maybeSingle();
          if (advRes != null) {
            final txnsRes = await client
                .from('advance_transactions')
                .select('amount_paise, txn_type')
                .eq('advance_id', advRes['id']);
            for (final t in (txnsRes as List<dynamic>)) {
              final amt = (t['amount_paise'] as num?)?.toInt() ?? 0;
              final type = t['txn_type'] as String?;
              if (type == 'refunded' || type == 'applied') {
                advance -= amt.abs();
              } else {
                advance += amt;
              }
            }
          }
        } catch (_) {}

        // 2. Fetch rent rate & electricity config
        try {
          final roomRes = await client
              .from('rooms')
              .select('rent_rate_paise, electricity_mode, per_unit_rate_paise, initial_meter_reading')
              .eq('tenancy_id', tId)
              .maybeSingle();
          if (roomRes != null) {
            rentRate = (roomRes['rent_rate_paise'] as num?)?.toInt() ?? 0;
            elecMode = (roomRes['electricity_mode'] as String?) ?? 'metered';
            elecRate = (roomRes['per_unit_rate_paise'] as num?)?.toInt() ?? 900;
            initReading = (roomRes['initial_meter_reading'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (_) {}

        try {
          final elecRes = await client
              .from('electricity_config')
              .select('mode, initial_reading, fixed_amount_paise')
              .eq('tenancy_id', tId)
              .maybeSingle();
          if (elecRes != null) {
            elecMode = (elecRes['mode'] as String?) ?? elecMode;
            if (elecRes['initial_reading'] != null) {
              initReading = (elecRes['initial_reading'] as num?)?.toDouble() ?? initReading;
            }
            fixedAmt = (elecRes['fixed_amount_paise'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}

      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tenancyData = tenancy;
        _advanceBalancePaise = advance;
        _rentRatePaise = rentRate;
        _electricityRatePaise = elecRate;
        _electricityMode = elecMode;
        _initialMeterReading = initReading;
        _fixedElecAmountPaise = fixedAmt;
        _isBiometricSupported = supported;
        _isBiometricEnabled = enabled;
      });
    } catch (e) {
      debugPrint('Error loading tenant details: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out of your Rentify tenant account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      ref.read(demoAuthProvider.notifier).logout();
      if (mounted) context.go(Routes.login);
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final t = _tenancyData;
    final tenantName = (t?['tenant_name'] as String?) ?? 'Tenant';
    final mobile = (t?['mobile'] as String?) ?? '—';
    final unitId = (t?['unit_id'] as String?) ?? 'Assigned Unit';
    final tenantType = (t?['tenant_type'] as String?) ?? 'Standard';
    final isActive = (t?['is_active'] as bool?) ?? true;
    final loginEnabled = (t?['login_enabled'] as bool?) ?? true;
    final notes = (t?['notes'] as String?)?.trim() ?? '';
    
    DateTime? startDate;
    if (t?['start_date'] != null) {
      startDate = DateTime.tryParse(t!['start_date'].toString());
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('My Tenancy Details', style: AppTextStyles.h2),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDetails();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Read-only Notice Banner ─────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.actionBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.action.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AppColors.action, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'These records are officially maintained by your landlord and cannot be edited by tenant.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.action, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tenant Profile & Room Card ──────────────────────────
            _SectionCard(
              title: 'Personal & Room Details',
              icon: Icons.person_outline_rounded,
              children: [
                _DetailRow(label: 'Tenant Full Name', value: tenantName),
                _DetailRow(label: 'Registered Mobile', value: mobile),
                _DetailRow(label: 'Assigned Room / Unit', value: unitId),
                _DetailRow(label: 'Tenant Category', value: tenantType.toUpperCase()),
                _DetailRow(
                  label: 'Tenancy Status',
                  customValue: StatusChip(
                    label: isActive ? 'Active Tenancy' : 'Inactive / Left',
                    type: isActive ? StatusChipType.success : StatusChipType.neutral,
                  ),
                ),
                _DetailRow(
                  label: 'Tenant Portal Access',
                  customValue: StatusChip(
                    label: loginEnabled ? 'Enabled' : 'Disabled',
                    type: loginEnabled ? StatusChipType.success : StatusChipType.error,
                  ),
                ),
                if (startDate != null)
                  _DetailRow(
                    label: 'Move-in / Start Date',
                    value: DateFormat('dd MMMM yyyy').format(startDate),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Financial Terms & Rates Card ─────────────────────────
            _SectionCard(
              title: 'Rental & Billing Terms',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                if (_rentRatePaise > 0)
                  _DetailRow(
                    label: 'Monthly Room Rent',
                    value: CurrencyFormatter.fromPaise(_rentRatePaise),
                  ),
                _DetailRow(
                  label: 'Advance / Security Deposit',
                  value: CurrencyFormatter.fromPaise(_advanceBalancePaise),
                ),
                _DetailRow(
                  label: 'Electricity Billing Mode',
                  value: _electricityMode.toLowerCase() == 'fixed'
                      ? 'Fixed Monthly Charge'
                      : (_electricityMode.toLowerCase() == 'none'
                          ? 'Not Available / No Meter Needed'
                          : 'Metered Consumption'),
                ),
                if (_electricityMode.toLowerCase() == 'fixed') ...[
                  _DetailRow(
                    label: 'Fixed Electricity Amount',
                    value: '₹${(_fixedElecAmountPaise / 100).toStringAsFixed(0)} / month (Auto-billed, no readings needed)',
                  ),
                ],
                if (_electricityMode.toLowerCase() == 'none') ...[
                  const _DetailRow(
                    label: 'Electricity Status',
                    value: 'No meter needed (Included in rent)',
                  ),
                ],
                if (_electricityMode.toLowerCase() == 'meter' || _electricityMode.toLowerCase() == 'metered') ...[
                  _DetailRow(
                    label: 'Electricity Unit Rate',
                    value: '₹${(_electricityRatePaise / 100).toStringAsFixed(2)} / kWh unit',
                  ),
                  if (_initialMeterReading > 0)
                    _DetailRow(
                      label: 'Initial Meter Reading',
                      value: '${_initialMeterReading.toStringAsFixed(1)} units',
                    ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Landlord Comments / Notes ───────────────────────────
            if (notes.isNotEmpty) ...[
              _SectionCard(
                title: 'Landlord Notes & Instructions',
                icon: Icons.notes_rounded,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      notes,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],


            // ── Security & App Settings ─────────────────────────────
            _SectionCard(
              title: 'App Security & Preferences',
              icon: Icons.shield_outlined,
              children: [
                if (_isBiometricSupported) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Biometric Quick Unlock', style: AppTextStyles.bodyMedium),
                    subtitle: Text(
                      'Always require fingerprint or face unlock when opening Rentify',
                      style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                    ),
                    value: _isBiometricEnabled,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await BiometricService.setBiometricEnabled(val);
                      if (success && mounted) {
                        setState(() => _isBiometricEnabled = val);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(val
                                ? 'Biometric unlock enabled. App will lock when minimized.'
                                : 'Biometric unlock disabled.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 24),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.system_update_rounded, color: AppColors.action),
                  title: Text('App Version: ${UpdateService.currentAppVersion}', style: AppTextStyles.bodyMedium),
                  subtitle: const Text('Check for new releases and APK downloads'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => UpdateService.checkForUpdates(context, isManual: true),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text('Sign Out', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                  subtitle: const Text('Log out of this device'),
                  onTap: _handleSignOut,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.action, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.customValue,
  });

  final String label;
  final String? value;
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted),
            ),
          ),
          const SizedBox(width: 12),
          customValue ??
              Expanded(
                flex: 3,
                child: Text(
                  value ?? '—',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.end,
                ),
              ),
        ],
      ),
    );
  }
}
