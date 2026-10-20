import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/app_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utilities/avatar_helper.dart';
import '../../../core/utilities/currency_formatter.dart';

/// Reports screen — month-scoped summary, per-tenant breakdown, and real CSV export
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _selectedPeriod;
  late final List<DateTime> _availableMonths;
  bool _isLoading = true;
  String? _errorMessage;
  _ReportData? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Compute last day of the current calendar month
    final lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final isCurrentMonthEnded = now.day >= lastDayOfCurrentMonth;

    // Only show current month once the 31st (or last day) completes; otherwise latest is previous month
    final latestReportMonth = isCurrentMonthEnded
        ? DateTime(now.year, now.month, 1)
        : DateTime(now.year, now.month - 1, 1);

    _selectedPeriod = latestReportMonth;

    // Generate dynamic list of past 24 completed months
    _availableMonths = List.generate(24, (i) {
      return DateTime(latestReportMonth.year, latestReportMonth.month - i, 1);
    });

    _load();
  }

  String get _canonicalBillingMonth =>
      '${_selectedPeriod.year}-${_selectedPeriod.month.toString().padLeft(2, '0')}-01';

  String get _displayMonth => DateFormat('MMMM yyyy').format(_selectedPeriod);

  Future<void> _load() async {
    final cached = AppCacheService.get<_ReportData>('report_$_canonicalBillingMonth');
    if (cached != null && _data == null) {
      _data = cached;
      _isLoading = false;
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final client = Supabase.instance.client;
      final canonicalMonth = _canonicalBillingMonth;
      final startOfMonth = DateTime(_selectedPeriod.year, _selectedPeriod.month, 1);
      final startOfNextMonth = DateTime(_selectedPeriod.year, _selectedPeriod.month + 1, 1);

      // 1. Tenancies active during or started before this month
      final tenanciesRes = await client
          .from('tenancies')
          .select('id, tenant_name, unit_id, start_date, is_active')
          .order('unit_id', ascending: true);

      final List<dynamic> tenancies = tenanciesRes as List<dynamic>;

      // 2. Query charge allocation totals for this canonical month
      final allocRes = await client
          .from('charge_allocation_totals')
          .select('charge_id, tenancy_id, charge_type, billing_month, amount_paise, allocated_paise, outstanding_paise')
          .eq('billing_month', canonicalMonth);

      final List<dynamic> allocations = allocRes as List<dynamic>;

      // 3. Query payments collected strictly within this calendar month
      final paymentsRes = await client
          .from('payments')
          .select('id, tenancy_id, amount_paise, payment_date, method')
          .gte('payment_date', startOfMonth.toIso8601String().substring(0, 10))
          .lt('payment_date', startOfNextMonth.toIso8601String().substring(0, 10));

      final List<dynamic> payments = paymentsRes as List<dynamic>;

      // Aggregate global metrics
      int totalChargedPaise = 0;
      int rentChargedPaise = 0;
      int elecChargedPaise = 0;
      int chargesSettledPaise = 0;
      int outstandingPaise = 0;

      for (final a in allocations) {
        final amt = ((a['amount_paise'] as num?) ?? 0).toInt();
        final alloc = ((a['allocated_paise'] as num?) ?? 0).toInt();
        final out = ((a['outstanding_paise'] as num?) ?? 0).toInt();
        final cType = (a['charge_type'] as String?) ?? 'rent';

        totalChargedPaise += amt;
        chargesSettledPaise += alloc;
        outstandingPaise += out;

        if (cType == 'rent') {
          rentChargedPaise += amt;
        } else if (cType == 'electricity') {
          elecChargedPaise += amt;
        }
      }

      int totalCollectedInMonthPaise = 0;
      for (final p in payments) {
        totalCollectedInMonthPaise += ((p['amount_paise'] as num?) ?? 0).toInt();
      }

      // Build per-tenant report rows
      final rows = <_ReportRowData>[];
      int fullyPaidTenants = 0;
      int activeTenantsCount = 0;

      for (final t in tenancies) {
        final tId = t['id'] as String;
        final tName = (t['tenant_name'] as String?) ?? 'Tenant';
        final tUnit = (t['unit_id'] as String?) ?? '—';
        final tIsActive = (t['is_active'] as bool?) ?? true;

        if (tIsActive) activeTenantsCount++;

        final tAllocs = allocations.where((a) => a['tenancy_id'] == tId).toList();
        final tPayments = payments.where((p) => p['tenancy_id'] == tId).toList();

        int tRentCharged = 0;
        int tElecCharged = 0;
        int tCharged = 0;
        int tSettled = 0;
        int tOut = 0;

        for (final a in tAllocs) {
          final amt = ((a['amount_paise'] as num?) ?? 0).toInt();
          final alloc = ((a['allocated_paise'] as num?) ?? 0).toInt();
          final out = ((a['outstanding_paise'] as num?) ?? 0).toInt();
          final cType = (a['charge_type'] as String?) ?? 'rent';

          tCharged += amt;
          tSettled += alloc;
          tOut += out;

          if (cType == 'rent') tRentCharged += amt;
          if (cType == 'electricity') tElecCharged += amt;
        }

        int tCollectedThisMonth = 0;
        for (final p in tPayments) {
          tCollectedThisMonth += ((p['amount_paise'] as num?) ?? 0).toInt();
        }

        String tenantStatus;
        if (tCharged == 0) {
          tenantStatus = 'no_charge';
        } else if (tOut == 0) {
          tenantStatus = 'paid';
          fullyPaidTenants++;
        } else if (tSettled > 0) {
          tenantStatus = 'partial';
        } else {
          tenantStatus = 'unpaid';
        }

        // Include in table if tenant has charges, collections, or is active
        if (tCharged > 0 || tCollectedThisMonth > 0 || tIsActive) {
          rows.add(_ReportRowData(
            tenancyId: tId,
            name: tName,
            unit: tUnit,
            rentChargedPaise: tRentCharged,
            elecChargedPaise: tElecCharged,
            totalChargedPaise: tCharged,
            settledPaise: tSettled,
            collectedThisMonthPaise: tCollectedThisMonth,
            outstandingPaise: tOut,
            status: tenantStatus,
          ));
        }
      }

      if (!mounted) return;
      final repData = _ReportData(
        billingMonth: canonicalMonth,
        displayMonth: _displayMonth,
        totalChargedPaise: totalChargedPaise,
        rentChargedPaise: rentChargedPaise,
        elecChargedPaise: elecChargedPaise,
        chargesSettledPaise: chargesSettledPaise,
        totalCollectedInMonthPaise: totalCollectedInMonthPaise,
        outstandingPaise: outstandingPaise,
        paidTenantsCount: fullyPaidTenants,
        totalActiveTenants: activeTenantsCount,
        rows: rows,
      );
      AppCacheService.set('report_$_canonicalBillingMonth', repData);

      setState(() {
        _isLoading = false;
        _data = repData;
      });
    } catch (e) {
      debugPrint('Error loading monthly report: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load report data: $e';
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_data == null || _data!.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this month.')),
      );
      return;
    }

    final csv = StringBuffer();
    // Headers & metadata
    csv.writeln('Rentify Monthly Financial Report');
    csv.writeln('Billing Period,"${_data!.displayMonth}" (${_data!.billingMonth})');
    csv.writeln('Generated At,"${DateTime.now().toIso8601String()}"');
    csv.writeln('Total Charged (INR),${(_data!.totalChargedPaise / 100).toStringAsFixed(2)}');
    csv.writeln('Rent Charged (INR),${(_data!.rentChargedPaise / 100).toStringAsFixed(2)}');
    csv.writeln('Electricity Charged (INR),${(_data!.elecChargedPaise / 100).toStringAsFixed(2)}');
    csv.writeln('Charges Settled (INR),${(_data!.chargesSettledPaise / 100).toStringAsFixed(2)}');
    csv.writeln('Payments Collected in Month (INR),${(_data!.totalCollectedInMonthPaise / 100).toStringAsFixed(2)}');
    csv.writeln('Outstanding Balance (INR),${(_data!.outstandingPaise / 100).toStringAsFixed(2)}');
    csv.writeln('Settlement Rate,${(_data!.settlementRate * 100).toStringAsFixed(1)}%');
    csv.writeln('');
    csv.writeln('Tenant Name,Unit,Rent Charged (INR),Electricity Charged (INR),Total Charged (INR),Settled (INR),Collected In Month (INR),Outstanding (INR),Status');

    for (final r in _data!.rows) {
      final cleanName = r.name.replaceAll('"', '""');
      final cleanUnit = r.unit.replaceAll('"', '""');
      csv.writeln(
        '"$cleanName","$cleanUnit",'
        '${(r.rentChargedPaise / 100).toStringAsFixed(2)},'
        '${(r.elecChargedPaise / 100).toStringAsFixed(2)},'
        '${(r.totalChargedPaise / 100).toStringAsFixed(2)},'
        '${(r.settledPaise / 100).toStringAsFixed(2)},'
        '${(r.collectedThisMonthPaise / 100).toStringAsFixed(2)},'
        '${(r.outstandingPaise / 100).toStringAsFixed(2)},'
        '${r.status.toUpperCase()}',
      );
    }

    final csvString = csv.toString();
    final filename = 'rentify_report_${_data!.billingMonth.substring(0, 7)}.csv';

    try {
      final uri = Uri.dataFromString(csvString, mimeType: 'text/csv', encoding: utf8);
      if (kIsWeb) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: csvString));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report copied to clipboard ($filename). Ready to paste/share!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csvString));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report CSV copied to clipboard ($filename)'),
            backgroundColor: AppColors.action,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Reports', style: AppTextStyles.h2),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Dynamic Month selector
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.action),
                const SizedBox(width: 8),
                Text('Period:', style: AppTextStyles.bodyMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableMonths.length,
                      itemBuilder: (_, i) {
                        final dt = _availableMonths[i];
                        final isSelected = dt.year == _selectedPeriod.year &&
                            dt.month == _selectedPeriod.month;
                        final label = DateFormat('MMM yyyy').format(dt);

                        return GestureDetector(
                          onTap: () {
                            if (isSelected) return;
                            setState(() => _selectedPeriod = dt);
                            _load();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.action : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: AppTextStyles.captionBold.copyWith(
                                  color: isSelected ? Colors.white : AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Summary stats
                            _SummaryRow(data: _data!),
                            const SizedBox(height: 16),

                            // Charge Breakdown
                            _ChargeTypeBreakdown(data: _data!),
                            const SizedBox(height: 16),

                            // Collection Rate
                            _CollectionRate(data: _data!),
                            const SizedBox(height: 20),

                            // Table header & Per-tenant breakdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Per-tenant breakdown', style: AppTextStyles.h3),
                                Text(
                                  '${_data!.rows.length} records',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (_data!.rows.isEmpty ||
                                (_data!.totalChargedPaise == 0 &&
                                    _data!.totalCollectedInMonthPaise == 0))
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Column(
                                    children: [
                                      Icon(Icons.analytics_outlined, size: 48, color: AppColors.inkMuted),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No report data available for $_displayMonth',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'No charges or collections found for this specific billing period.',
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton(
                                        onPressed: () {
                                          final now = DateTime.now();
                                          setState(() => _selectedPeriod = DateTime(now.year, now.month, 1));
                                          _load();
                                        },
                                        child: const Text('Go to current month'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              // Column headers
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Tenant', style: AppTextStyles.captionBold)),
                                    Expanded(flex: 2, child: Text('Charged', style: AppTextStyles.captionBold, textAlign: TextAlign.right)),
                                    Expanded(flex: 2, child: Text('Settled', style: AppTextStyles.captionBold, textAlign: TextAlign.right)),
                                    Expanded(flex: 2, child: Text('Due', style: AppTextStyles.captionBold, textAlign: TextAlign.right)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              ..._data!.rows.map((r) => _ReportRow(row: r)),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Cards ─────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});
  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total charged',
            value: CurrencyFormatter.fromPaise(data.totalChargedPaise),
            icon: Icons.receipt_long_outlined,
            color: AppColors.action,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Collected in mo.',
            value: CurrencyFormatter.fromPaise(data.totalCollectedInMonthPaise),
            icon: Icons.payments_outlined,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Outstanding',
            value: CurrencyFormatter.fromPaise(data.outstandingPaise),
            icon: Icons.account_balance_wallet_outlined,
            color: data.outstandingPaise > 0 ? AppColors.amountDue : AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.currencySmall.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ChargeTypeBreakdown extends StatelessWidget {
  const _ChargeTypeBreakdown({required this.data});
  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SubBreakdown(
            icon: Icons.home_outlined,
            label: 'Room rent',
            amount: CurrencyFormatter.fromPaise(data.rentChargedPaise),
            color: AppColors.action,
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          _SubBreakdown(
            icon: Icons.bolt_outlined,
            label: 'Electricity',
            amount: CurrencyFormatter.fromPaise(data.elecChargedPaise),
            color: AppColors.warning,
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          _SubBreakdown(
            icon: Icons.check_circle_outline,
            label: 'Settled dues',
            amount: CurrencyFormatter.fromPaise(data.chargesSettledPaise),
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _SubBreakdown extends StatelessWidget {
  const _SubBreakdown({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });
  final IconData icon;
  final String label, amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(amount, style: AppTextStyles.bodyMedium.copyWith(color: color)),
          ],
        ),
      ],
    );
  }
}

class _CollectionRate extends StatelessWidget {
  const _CollectionRate({required this.data});
  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final rate = data.settlementRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Month settlement rate', style: AppTextStyles.h3),
              Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.currencyMedium.copyWith(
                  color: rate > 0.8
                      ? AppColors.success
                      : rate > 0.5
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(
                rate > 0.8
                    ? AppColors.success
                    : rate > 0.5
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.paidTenantsCount} of ${data.totalActiveTenants} active residents fully cleared for ${data.displayMonth}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.row});
  final _ReportRowData row;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('${Routes.tenantProfile}/${row.tenancyId}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  AvatarHelper.buildAvatar(name: row.name, radius: 14, fontSize: 11),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            Text(row.unit, style: AppTextStyles.caption),
                            const SizedBox(width: 6),
                            _StatusBadge(status: row.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.fromPaise(row.totalChargedPaise),
                style: AppTextStyles.currencySmall,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.fromPaise(row.settledPaise),
                style: AppTextStyles.currencySmall.copyWith(color: AppColors.success),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.fromPaise(row.outstandingPaise),
                style: AppTextStyles.currencySmall.copyWith(
                  color: row.outstandingPaise > 0 ? AppColors.amountDue : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'paid' => ('PAID', AppColors.success, AppColors.successBg),
      'partial' => ('PARTIAL', AppColors.warning, AppColors.warningBg),
      'unpaid' => ('DUE', AppColors.error, AppColors.errorBg),
      _ => ('NO BILL', AppColors.inkMuted, AppColors.surfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────

class _ReportData {
  final String billingMonth;
  final String displayMonth;
  final int totalChargedPaise;
  final int rentChargedPaise;
  final int elecChargedPaise;
  final int chargesSettledPaise;
  final int totalCollectedInMonthPaise;
  final int outstandingPaise;
  final int paidTenantsCount;
  final int totalActiveTenants;
  final List<_ReportRowData> rows;

  const _ReportData({
    required this.billingMonth,
    required this.displayMonth,
    required this.totalChargedPaise,
    required this.rentChargedPaise,
    required this.elecChargedPaise,
    required this.chargesSettledPaise,
    required this.totalCollectedInMonthPaise,
    required this.outstandingPaise,
    required this.paidTenantsCount,
    required this.totalActiveTenants,
    required this.rows,
  });

  double get settlementRate => totalChargedPaise > 0
      ? (chargesSettledPaise / totalChargedPaise).clamp(0.0, 1.0)
      : 0.0;
}

class _ReportRowData {
  final String tenancyId, name, unit;
  final int rentChargedPaise;
  final int elecChargedPaise;
  final int totalChargedPaise;
  final int settledPaise;
  final int collectedThisMonthPaise;
  final int outstandingPaise;
  final String status;

  const _ReportRowData({
    required this.tenancyId,
    required this.name,
    required this.unit,
    required this.rentChargedPaise,
    required this.elecChargedPaise,
    required this.totalChargedPaise,
    required this.settledPaise,
    required this.collectedThisMonthPaise,
    required this.outstandingPaise,
    required this.status,
  });
}
