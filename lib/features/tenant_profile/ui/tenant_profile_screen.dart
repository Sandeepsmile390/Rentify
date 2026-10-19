import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../tenants/services/tenancy_service.dart';
import 'package:intl/intl.dart';

/// Figma frame 09 — Tenant profile financial overview (admin view)
class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key, required this.tenancyId});
  final String tenancyId;

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _isLoading = true;
  _ProfileData? _data;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final canonicalMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

      // 1. Tenancy
      final tenancy = await client
          .from('tenancies')
          .select('id, profile_id, unit_id, tenant_type, tenant_name, mobile, start_date, is_active, notes, login_enabled')
          .eq('id', widget.tenancyId)
          .maybeSingle();

      if (tenancy == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _data = _ProfileData.placeholder(widget.tenancyId);
        });
        return;
      }

      final name = (tenancy['tenant_name'] as String?) ?? 'Tenant';
      final mobile = (tenancy['mobile'] as String?) ?? '';
      final unitId = (tenancy['unit_id'] as String?) ?? '—';
      final type = (tenancy['tenant_type'] as String?) == 'shop' ? 'Shop' : 'Room';
      final startDate = (tenancy['start_date'] as String?) ?? '';
      final isActive = (tenancy['is_active'] as bool?) ?? true;
      final loginEnabled = (tenancy['login_enabled'] as bool?) ?? true;

      // 2. Rent rate
      int currentRentPaise = 0;
      String rentEffectiveFrom = startDate;
      final rentRes = await client
          .from('rent_rates')
          .select('amount_paise, effective_from')
          .eq('tenancy_id', widget.tenancyId)
          .order('effective_from', ascending: false)
          .limit(1)
          .maybeSingle();
      if (rentRes != null) {
        currentRentPaise = (rentRes['amount_paise'] as num?)?.toInt() ?? 0;
        rentEffectiveFrom = (rentRes['effective_from'] as String?) ?? startDate;
      }

      // 3. Electricity config
      String elecMode = 'meter';
      final elecRes = await client
          .from('electricity_config')
          .select('mode')
          .eq('tenancy_id', widget.tenancyId)
          .maybeSingle();
      if (elecRes != null) {
        elecMode = (elecRes['mode'] as String?) ?? 'meter';
      }

      // 4. Last meter reading
      double lastMeter = 0.0;
      final meterRes = await client
          .from('meter_readings')
          .select('current_reading')
          .eq('tenancy_id', widget.tenancyId)
          .order('reading_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (meterRes != null) {
        lastMeter = (meterRes['current_reading'] as num?)?.toDouble() ?? 0.0;
      }

      // 5. Query charge allocation totals view
      final allocRes = await client
          .from('charge_allocation_totals')
          .select('charge_id, charge_type, billing_month, amount_paise, allocated_paise, outstanding_paise')
          .eq('tenancy_id', widget.tenancyId)
          .order('billing_month', ascending: false);

      int rentDuePaise = 0;
      int elecDuePaise = 0;
      int currentElecPaise = 0;
      Map<String, dynamic>? currentCanonicalElecCharge;

      final List<_ChargeItem> chargeItems = [];

      for (final r in (allocRes as List<dynamic>)) {
        final cType = (r['charge_type'] as String?) ?? 'rent';
        final amt = (r['amount_paise'] as num?)?.toInt() ?? 0;
        final out = (r['outstanding_paise'] as num?)?.toInt() ?? 0;
        final alloc = (r['allocated_paise'] as num?)?.toInt() ?? 0;
        final month = (r['billing_month'] as String?) ?? '';

        if (out > 0) {
          if (cType == 'rent') rentDuePaise += out;
          if (cType == 'electricity') elecDuePaise += out;
        }

        if (month == canonicalMonth) {
          if (cType == 'rent' && amt > 0) {
            currentRentPaise = amt;
          } else if (cType == 'electricity') {
            currentCanonicalElecCharge = r as Map<String, dynamic>;
            currentElecPaise = amt;
          }
        }

        String itemStatus;
        if (out == 0) {
          itemStatus = 'paid';
        } else if (alloc > 0) {
          itemStatus = 'partial';
        } else {
          itemStatus = 'pending';
        }

        chargeItems.add(_ChargeItem(
          label: cType == 'electricity' ? 'Electricity' : 'Rent',
          month: month,
          amountPaise: amt,
          type: cType,
          status: itemStatus,
        ));
      }

      // Electricity status for canonical month
      String elecStatus;
      if (elecMode == 'meter') {
        if (currentCanonicalElecCharge != null) {
          final amt = (currentCanonicalElecCharge['amount_paise'] as num?)?.toInt() ?? 0;
          final out = (currentCanonicalElecCharge['outstanding_paise'] as num?)?.toInt() ?? 0;
          final alloc = (currentCanonicalElecCharge['allocated_paise'] as num?)?.toInt() ?? 0;

          if (out == 0 && amt > 0) {
            elecStatus = 'Paid (${CurrencyFormatter.fromPaise(amt)})';
          } else if (out == 0 && amt == 0) {
            elecStatus = '₹0 (0 units consumed)';
          } else if (alloc > 0) {
            elecStatus = '${CurrencyFormatter.fromPaise(out)} due (Partially paid)';
          } else {
            elecStatus = '${CurrencyFormatter.fromPaise(out)} due';
          }
        } else {
          // Check if meter reading exists for canonical month
          final readingRes = await client
              .from('meter_readings')
              .select('id, current_reading')
              .eq('tenancy_id', widget.tenancyId)
              .eq('billing_month', canonicalMonth)
              .maybeSingle();

          if (readingRes != null) {
            elecStatus = 'Reading saved / charge pending';
          } else {
            elecStatus = 'Awaiting reading';
          }
        }
      } else if (elecMode == 'fixed') {
        elecStatus = CurrencyFormatter.fromPaise(currentElecPaise);
      } else {
        elecStatus = 'No charge required';
      }

      // 6. Payments
      final paymentsRes = await client
          .from('payments')
          .select('amount_paise, payment_date, method, reference')
          .eq('tenancy_id', widget.tenancyId)
          .order('payment_date', ascending: false);

      int paymentsThisMonthPaise = 0;
      final currentMonthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final List<_PaymentItem> paymentItems = [];

      for (final p in (paymentsRes as List<dynamic>)) {
        final amt = (p['amount_paise'] as num?)?.toInt() ?? 0;
        final pDate = (p['payment_date'] as String?) ?? '';
        final method = (p['method'] as String?) ?? 'cash';
        final ref = p['reference'] as String?;

        if (pDate.startsWith(currentMonthPrefix)) {
          paymentsThisMonthPaise += amt;
        }

        paymentItems.add(_PaymentItem(
          date: pDate,
          amountPaise: amt,
          method: method == 'online' ? 'Online' : 'Cash',
          reference: ref,
        ));
      }

      // 7. Advance balance
      int advanceBalancePaise = 0;
      final advRes = await client
          .from('tenant_advances')
          .select('id')
          .eq('tenancy_id', widget.tenancyId)
          .maybeSingle();

      if (advRes != null) {
        final txnsRes = await client
            .from('advance_transactions')
            .select('amount_paise')
            .eq('advance_id', advRes['id']);
        for (final t in (txnsRes as List<dynamic>)) {
          advanceBalancePaise += ((t['amount_paise'] as num?)?.toInt() ?? 0);
        }
      }

      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final currentBillingMonth = '${monthNames[now.month - 1]} ${now.year}';

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _data = _ProfileData(
          name: name,
          mobile: mobile,
          unitId: unitId,
          type: type,
          billingMonth: currentBillingMonth,
          rentEffectiveFrom: rentEffectiveFrom,
          startDate: startDate,
          elecMode: elecMode,
          isActive: isActive,
          loginEnabled: loginEnabled,
          rentDuePaise: rentDuePaise,
          elecDuePaise: elecDuePaise,
          advanceBalancePaise: advanceBalancePaise,
          currentRentPaise: currentRentPaise,
          currentElecPaise: currentElecPaise,
          elecStatus: elecStatus,
          paymentsThisMonthPaise: paymentsThisMonthPaise,
          lastMeterReading: lastMeter,
          charges: chargeItems,
          payments: paymentItems,
        );
      });
    } catch (e) {
      debugPrint('Error loading tenant profile: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _data = _ProfileData.placeholder(widget.tenancyId);
      });
    }
  }

  Future<void> _handleToggleLogin(bool enabled) async {
    try {
      final client = Supabase.instance.client;
      await client.rpc('admin_toggle_tenant_login', params: {
        'p_tenancy_id': widget.tenancyId,
        'p_enabled': enabled,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'Tenant login enabled. Resident can access portal.'
              : 'Tenant login disabled. Active sessions revoked.'),
          backgroundColor: enabled ? AppColors.success : AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update tenant login: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (ctx, _) => [
                _ProfileAppBar(
                  data: _data!,
                  tenancyId: widget.tenancyId,
                  onRefresh: _load,
                ),
                _FinancialSummaryBar(data: _data!, isWide: isWide),
                _TabBar(controller: _tabCtrl),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _OverviewTab(
                      data: _data!,
                      tenancyId: widget.tenancyId,
                      onRefresh: _load,
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _ChargesTab(data: _data!),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _PaymentsTab(data: _data!),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _DetailsTab(
                      data: _data!,
                      tenancyId: widget.tenancyId,
                      onToggleLogin: _handleToggleLogin,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.pushNamed(
                  'record-payment',
                  pathParameters: {'tenancyId': widget.tenancyId},
                );
                await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record payment'),
              tooltip: 'Record a payment for this tenant',
            ),
    );
  }
}

// ── Profile app bar ───────────────────────────────────────────────

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({
    required this.data,
    required this.tenancyId,
    required this.onRefresh,
  });
  final _ProfileData data;
  final String tenancyId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.navy,
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Text(
                  data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.name,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${data.unitId} · ${data.type}',
                            style: AppTextStyles.captionBold.copyWith(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          label: data.isActive ? 'Active' : 'Inactive',
                          type: data.isActive ? StatusChipType.success : StatusChipType.neutral,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.electric_meter_outlined, color: Colors.white),
          tooltip: 'Enter meter reading',
          onPressed: () async {
            final updated = await context.pushNamed(
              'meter-reading',
              pathParameters: {'tenancyId': tenancyId},
            );
            if (updated == true) {
              await onRefresh();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          tooltip: 'Delete tenant',
          onPressed: () => _confirmDeleteTenant(context, tenancyId, data.name),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          tooltip: 'More actions',
          onPressed: () => _showActionsSheet(context),
        ),
      ],
    );
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: const Text('Advance / Deposit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.pushNamed('advances', pathParameters: {'tenancyId': tenancyId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Audit trail'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.pushNamed('audit-trail', pathParameters: {'tenancyId': tenancyId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
              title: const Text('Send WhatsApp dues summary'),
              subtitle: const Text('Exact breakdown or fully-cleared notice'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _sendWhatsAppDuesSummary(context, data, tenancyId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.password_rounded, color: AppColors.action),
              title: const Text('Set / Reset tenant password'),
              subtitle: const Text('Configure portal password for this resident'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showSetPasswordDialog(context, tenancyId, data.name, data.mobile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Documents'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.pushNamed('documents', pathParameters: {'tenancyId': tenancyId});
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              title: const Text('Delete tenant', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDeleteTenant(context, tenancyId, data.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Financial summary bar ─────────────────────────────────────────

class _FinancialSummaryBar extends StatelessWidget {
  const _FinancialSummaryBar({required this.data, required this.isWide});
  final _ProfileData data;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: isWide
            ? Row(
                children: [
                  _FinStat(label: 'Rent due', value: CurrencyFormatter.fromPaise(data.rentDuePaise), color: data.rentDuePaise > 0 ? AppColors.amountDue : AppColors.success),
                  _Divider(),
                  _FinStat(label: 'Electricity due', value: CurrencyFormatter.fromPaise(data.elecDuePaise), color: data.elecDuePaise > 0 ? AppColors.warning : AppColors.success),
                  _Divider(),
                  _FinStat(label: 'Advance balance', value: CurrencyFormatter.fromPaise(data.advanceBalancePaise), color: AppColors.action),
                  _Divider(),
                  _FinStat(label: 'Total outstanding', value: CurrencyFormatter.fromPaise(data.totalDuePaise), color: data.totalDuePaise > 0 ? AppColors.amountDue : AppColors.success, isLarge: true),
                ],
              )
            : Column(
                children: [
                  Row(children: [
                    Expanded(child: _FinStat(label: 'Rent due', value: CurrencyFormatter.fromPaise(data.rentDuePaise), color: data.rentDuePaise > 0 ? AppColors.amountDue : AppColors.success)),
                    Container(width: 1, height: 40, color: AppColors.border),
                    Expanded(child: _FinStat(label: 'Electricity due', value: CurrencyFormatter.fromPaise(data.elecDuePaise), color: data.elecDuePaise > 0 ? AppColors.warning : AppColors.success)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: data.totalDuePaise > 0 ? AppColors.errorBg : AppColors.successBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: data.totalDuePaise > 0 ? AppColors.errorBorder : AppColors.successBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total outstanding', style: AppTextStyles.bodyMedium),
                        Text(
                          CurrencyFormatter.fromPaise(data.totalDuePaise),
                          style: AppTextStyles.currencyMedium.copyWith(
                            color: data.totalDuePaise > 0 ? AppColors.amountDue : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FinStat extends StatelessWidget {
  const _FinStat({required this.label, required this.value, required this.color, this.isLarge = false});
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: (isLarge ? AppTextStyles.currencyMedium : AppTextStyles.currencySmall)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

// ── Tab bar ───────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        child: TabBar(
          controller: controller,
          labelStyle: AppTextStyles.captionBold,
          unselectedLabelStyle: AppTextStyles.caption,
          labelColor: AppColors.action,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.action,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Charges'),
            Tab(text: 'Payments'),
            Tab(text: 'Details'),
          ],
        ),
      ),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.data,
    required this.tenancyId,
    required this.onRefresh,
  });
  final _ProfileData data;
  final String tenancyId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick actions
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Record payment',
                type: AppButtonType.primary,
                icon: Icons.payments_outlined,
                onPressed: () async {
                  await context.pushNamed(
                    'record-payment',
                    pathParameters: {'tenancyId': tenancyId},
                  );
                  await onRefresh();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Meter reading',
                type: AppButtonType.outlined,
                icon: Icons.electric_meter_outlined,
                onPressed: () async {
                  final updated = await context.pushNamed(
                    'meter-reading',
                    pathParameters: {'tenancyId': tenancyId},
                  );
                  if (updated == true) {
                    await onRefresh();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Current month summary
        _SectionCard(
          title: 'This month',
          child: Column(
            children: [
              _InfoRow('Billing month', data.billingMonth),
              _InfoRow('Rent charge', CurrencyFormatter.fromPaise(data.currentRentPaise)),
              _InfoRow('Electricity charge', data.elecStatus),
              _InfoRow('Payments received', CurrencyFormatter.fromPaise(data.paymentsThisMonthPaise)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rent info
        _SectionCard(
          title: 'Rent',
          child: Column(
            children: [
              _InfoRow('Current rate', '${CurrencyFormatter.fromPaise(data.currentRentPaise)}/month'),
              _InfoRow('Effective from', data.rentEffectiveFrom),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Electricity
        _SectionCard(
          title: 'Electricity',
          child: Column(
            children: [
              _InfoRow('Mode', data.elecMode == 'meter' ? 'Meter-based' : data.elecMode == 'fixed' ? 'Fixed amount' : 'Not billed'),
              if (data.elecMode == 'meter')
                _InfoRow('Last reading', '${data.lastMeterReading.toStringAsFixed(1)} units'),
            ],
          ),
        ),
        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title, style: AppTextStyles.h3),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyRegular),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ── Charges tab ───────────────────────────────────────────────────

class _ChargesTab extends StatelessWidget {
  const _ChargesTab({required this.data});
  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.charges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = data.charges[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.type == 'rent' ? AppColors.actionBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  c.type == 'rent' ? Icons.home_outlined : Icons.bolt_rounded,
                  size: 18,
                  color: c.type == 'rent' ? AppColors.action : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.label, style: AppTextStyles.bodyMedium),
                  Text(c.month, style: AppTextStyles.caption),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(CurrencyFormatter.fromPaise(c.amountPaise), style: AppTextStyles.currencySmall),
                const SizedBox(height: 4),
                StatusChip(
                  label: _statusLabel(c.status),
                  type: _statusType(c.status),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String s) => switch (s) {
    'paid' => 'Paid',
    'partial' => 'Partial',
    'pending' => 'Pending',
    'waived' => 'Waived',
    _ => s,
  };

  StatusChipType _statusType(String s) => switch (s) {
    'paid' => StatusChipType.success,
    'partial' => StatusChipType.warning,
    'pending' => StatusChipType.error,
    'waived' => StatusChipType.neutral,
    _ => StatusChipType.neutral,
  };
}

// ── Payments tab ──────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.data});
  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = data.payments[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payments_outlined, size: 18, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.date, style: AppTextStyles.bodyMedium),
                  Text('${p.method} ${p.reference != null ? "· ${p.reference}" : ""}', style: AppTextStyles.caption),
                ]),
              ),
              Text(
                CurrencyFormatter.fromPaise(p.amountPaise),
                style: AppTextStyles.currencySmall.copyWith(color: AppColors.success),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Details tab ───────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.data,
    required this.tenancyId,
    required this.onToggleLogin,
  });
  final _ProfileData data;
  final String tenancyId;
  final void Function(bool) onToggleLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Tenancy details',
          child: Column(
            children: [
              _InfoRow('Unit ID', data.unitId),
              _InfoRow('Tenant type', data.type),
              _InfoRow('Start date', data.startDate),
              _InfoRow('Status', data.isActive ? 'Active' : 'Inactive'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Contact',
          child: Column(
            children: [
              _InfoRow('Name', data.name),
              _InfoRow('Mobile', data.mobile),
              if (data.email != null) _InfoRow('Email', data.email!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Portal access',
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text('Tenant login enabled', style: AppTextStyles.bodyMedium),
                subtitle: Text(
                  data.loginEnabled
                      ? 'Active — resident can log into tenant portal using mobile number'
                      : 'Disabled — portal login is blocked and active sessions are revoked',
                  style: AppTextStyles.caption.copyWith(
                    color: data.loginEnabled ? AppColors.success : AppColors.error,
                  ),
                ),
                value: data.loginEnabled,
                activeColor: AppColors.action,
                onChanged: onToggleLogin,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Danger zone',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Permanently remove this tenant and delete all their associated charges, payments, and meter readings.',
                style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text('Delete this tenant', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () => _confirmDeleteTenant(context, tenancyId, data.name),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Placeholder data ──────────────────────────────────────────────

class _ProfileData {
  final String name, mobile, unitId, type, billingMonth, rentEffectiveFrom, startDate, elecMode, elecStatus;
  final String? email;
  final bool isActive, loginEnabled;
  final int rentDuePaise, elecDuePaise, advanceBalancePaise, currentRentPaise, currentElecPaise, paymentsThisMonthPaise;
  final double lastMeterReading;
  final List<_ChargeItem> charges;
  final List<_PaymentItem> payments;

  const _ProfileData({
    required this.name, required this.mobile, required this.unitId,
    required this.type, required this.billingMonth, required this.rentEffectiveFrom,
    required this.startDate, required this.elecMode, required this.elecStatus,
    this.email, required this.isActive, required this.loginEnabled,
    required this.rentDuePaise, required this.elecDuePaise, required this.advanceBalancePaise,
    required this.currentRentPaise, required this.currentElecPaise, required this.paymentsThisMonthPaise,
    required this.lastMeterReading, required this.charges, required this.payments,
  });

  int get totalDuePaise => rentDuePaise + elecDuePaise;

  factory _ProfileData.placeholder(String id) => _ProfileData(
    name: 'Priya Sharma', mobile: '91234 56789', unitId: 'Room 07',
    type: 'Room', billingMonth: 'October 2026', rentEffectiveFrom: '01 Jan 2025',
    startDate: '01 Jan 2025', elecMode: 'meter', elecStatus: 'Awaiting reading', email: 'priya@example.com',
    isActive: true, loginEnabled: true, rentDuePaise: 550000, elecDuePaise: 135000,
    advanceBalancePaise: 1100000, currentRentPaise: 550000, currentElecPaise: 135000,
    paymentsThisMonthPaise: 0, lastMeterReading: 1450.5,
    charges: const [
      _ChargeItem(label: 'Rent', month: 'Oct 2026', amountPaise: 550000, type: 'rent', status: 'pending'),
      _ChargeItem(label: 'Electricity', month: 'Oct 2026', amountPaise: 135000, type: 'electricity', status: 'pending'),
      _ChargeItem(label: 'Rent', month: 'Sep 2026', amountPaise: 550000, type: 'rent', status: 'paid'),
      _ChargeItem(label: 'Electricity', month: 'Sep 2026', amountPaise: 98000, type: 'electricity', status: 'paid'),
    ],
    payments: const [
      _PaymentItem(date: '02 Sep 2026', amountPaise: 648000, method: 'Cash', reference: null),
      _PaymentItem(date: '05 Aug 2026', amountPaise: 648000, method: 'Online', reference: 'UPI/1234567'),
    ],
  );
}

class _ChargeItem {
  final String label, month, type, status;
  final int amountPaise;
  const _ChargeItem({required this.label, required this.month, required this.amountPaise, required this.type, required this.status});
}

class _PaymentItem {
  final String date, method;
  final String? reference;
  final int amountPaise;
  const _PaymentItem({required this.date, required this.amountPaise, required this.method, required this.reference});
}

Future<void> _confirmDeleteTenant(BuildContext context, String tenancyId, String tenantName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Delete from Database?'),
        ],
      ),
      content: Text(
        'Are you sure you want to permanently delete $tenantName from the database?\n\n'
        'This will permanently delete the tenancy and all related records (charges, payments, meter readings, and advance ledgers) from the database.\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete Permanently'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text('Deleting $tenantName from database…'),
        ],
      ),
      duration: const Duration(seconds: 15),
    ),
  );

  try {
    await TenancyService.deleteTenancyPermanently(tenancyId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tenant $tenantName deleted from database successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
    context.go(Routes.tenantDirectory);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to delete tenant: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

Future<void> _showSetPasswordDialog(
  BuildContext context,
  String tenancyId,
  String tenantName,
  String mobile,
) async {
  final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
  final defaultPass = cleanMobile.length >= 6 ? cleanMobile : 'RentifyTenant@2026';
  final passController = TextEditingController(text: defaultPass);
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text('Set Password for $tenantName'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set login password for $tenantName. By default, tenant User ID = mobile number ($mobile) and password = mobile number ($mobile).',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                helperText: 'Default: tenant mobile number ($cleanMobile)',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(dCtx);

            try {
              final client = Supabase.instance.client;
              await client.rpc('admin_set_tenant_password', params: {
                'p_tenancy_id': tenancyId,
                'p_new_password': passController.text.trim(),
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password set for $tenantName! They can now log in.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to set password: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          child: const Text('Save Password'),
        ),
      ],
    ),
  );
}

Future<void> _sendWhatsAppDuesSummary(
  BuildContext context,
  _ProfileData data,
  String tenancyId,
) async {
  try {
    final client = Supabase.instance.client;
    final allocRes = await client
        .from('charge_allocation_totals')
        .select('charge_type, billing_month, amount_paise, allocated_paise, outstanding_paise')
        .eq('tenancy_id', tenancyId)
        .order('billing_month', ascending: true);

    final List<OutstandingRentMonth> rentMonths = [];
    int totalRentDuePaise = 0;
    int totalElecDuePaise = 0;

    for (final r in (allocRes as List<dynamic>)) {
      final cType = (r['charge_type'] as String?) ?? 'rent';
      final out = (r['outstanding_paise'] as num?)?.toInt() ?? 0;
      final bMonth = (r['billing_month'] as String?) ?? '';

      if (out > 0) {
        if (cType == 'rent') {
          totalRentDuePaise += out;
          rentMonths.add(OutstandingRentMonth(
            billingMonth: bMonth,
            duePaise: out,
          ));
        } else if (cType == 'electricity') {
          totalElecDuePaise += out;
        }
      }
    }

    final payload = WhatsAppDuesSummaryPayload(
      tenantName: data.name,
      mobile: data.mobile,
      outstandingRentMonths: rentMonths,
      totalRentDuePaise: totalRentDuePaise,
      totalElecDuePaise: totalElecDuePaise,
    );

    await WhatsAppService.shareDuesSummary(context: context, payload: payload);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare WhatsApp dues notice: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

