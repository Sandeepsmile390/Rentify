import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/status_chip.dart';

/// Figma frames 02 & 03 — Tenant home + Tenant ledger (tenant-facing views)
class TenantLedgerScreen extends ConsumerStatefulWidget {
  const TenantLedgerScreen({super.key, this.isTenantHome = false});
  final bool isTenantHome;

  @override
  ConsumerState<TenantLedgerScreen> createState() => _TenantLedgerScreenState();
}

class _TenantLedgerScreenState extends ConsumerState<TenantLedgerScreen> {
  bool _isLoading = true;
  _TenantLedgerData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TODO: load from Supabase — scoped by auth.uid() via RLS
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _data = _TenantLedgerData.placeholder();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header app bar ────────────────────────────
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _TenantHeader(data: _data!),
                  ),
                  title: Text(
                    widget.isTenantHome ? 'My account' : 'My ledger',
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                  ),
                ),

                // ── Summary cards (home only) ─────────────────
                if (widget.isTenantHome)
                  SliverToBoxAdapter(
                    child: _SummarySection(data: _data!),
                  ),

                // ── Section title ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      widget.isTenantHome
                          ? 'Recent activity'
                          : 'Transaction history',
                      style: AppTextStyles.h3,
                    ),
                  ),
                ),

                // ── Ledger rows ───────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i >= _data!.entries.length) return null;
                      final e = _data!.entries[i];
                      return _LedgerRow(entry: e);
                    },
                    childCount: _data!.entries.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }
}

// ── Tenant header ─────────────────────────────────────────────────

class _TenantHeader extends StatelessWidget {
  const _TenantHeader({required this.data});
  final _TenantLedgerData data;

  @override
  Widget build(BuildContext context) {
    final hasDues = data.totalDuePaise > 0;
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${data.name.split(' ').first}',
            style: AppTextStyles.h2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.unitId} · ${data.billingMonth}',
            style: AppTextStyles.caption.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasDues ? AppColors.errorBg : AppColors.successBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasDues
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: hasDues ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  hasDues
                      ? 'Outstanding: ${CurrencyFormatter.fromPaise(data.totalDuePaise)}'
                      : 'All dues cleared ✓',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: hasDues ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary section ───────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.data});
  final _TenantLedgerData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Rent due',
                  value: CurrencyFormatter.fromPaise(data.rentDuePaise),
                  icon: Icons.home_outlined,
                  color: data.rentDuePaise > 0 ? AppColors.amountDue : AppColors.success,
                  bgColor: data.rentDuePaise > 0 ? AppColors.errorBg : AppColors.successBg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Electricity due',
                  value: CurrencyFormatter.fromPaise(data.elecDuePaise),
                  icon: Icons.bolt_rounded,
                  color: data.elecDuePaise > 0 ? AppColors.warning : AppColors.success,
                  bgColor: data.elecDuePaise > 0 ? AppColors.warningBg : AppColors.successBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            label: 'Advance / Security deposit balance',
            value: CurrencyFormatter.fromPaise(data.advanceBalancePaise),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.action,
            bgColor: AppColors.actionBg,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.fullWidth = false,
  });
  final String label, value;
  final IconData icon;
  final Color color, bgColor;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: fullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(label, style: AppTextStyles.bodyRegular),
                ]),
                Text(value, style: AppTextStyles.currencySmall.copyWith(color: color)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: AppTextStyles.currencyMedium.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(label, style: AppTextStyles.caption, maxLines: 1),
              ],
            ),
    );
  }
}

// ── Ledger row ────────────────────────────────────────────────────

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final _LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.type == 'payment';
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.successBg : AppColors.actionBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : _typeIcon(entry.subtype),
              size: 18,
              color: isCredit ? AppColors.success : AppColors.action,
            ),
          ),
          const SizedBox(width: 12),
          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(entry.date, style: AppTextStyles.caption),
                if (entry.note != null) ...[
                  const SizedBox(height: 2),
                  Text(entry.note!, style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                ],
              ],
            ),
          ),
          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isCredit
                    ? '+${CurrencyFormatter.fromPaise(entry.amountPaise)}'
                    : CurrencyFormatter.fromPaise(entry.amountPaise),
                style: AppTextStyles.currencySmall.copyWith(
                  color: isCredit ? AppColors.success : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.status != null) ...[
                const SizedBox(height: 4),
                StatusChip(
                  label: _statusLabel(entry.status!),
                  type: _statusChipType(entry.status!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String? subtype) => switch (subtype) {
    'rent' => Icons.home_outlined,
    'electricity' => Icons.bolt_rounded,
    _ => Icons.receipt_outlined,
  };

  String _statusLabel(String s) => switch (s) {
    'paid' => 'Paid',
    'partial' => 'Partial',
    'pending' => 'Pending',
    'waived' => 'Waived',
    _ => s,
  };

  StatusChipType _statusChipType(String s) => switch (s) {
    'paid' => StatusChipType.success,
    'partial' => StatusChipType.warning,
    'pending' => StatusChipType.error,
    _ => StatusChipType.neutral,
  };
}

// ── Data models ───────────────────────────────────────────────────

class _TenantLedgerData {
  final String name, unitId, billingMonth;
  final int rentDuePaise, elecDuePaise, advanceBalancePaise;
  final List<_LedgerEntry> entries;

  const _TenantLedgerData({
    required this.name, required this.unitId, required this.billingMonth,
    required this.rentDuePaise, required this.elecDuePaise,
    required this.advanceBalancePaise, required this.entries,
  });

  int get totalDuePaise => rentDuePaise + elecDuePaise;

  factory _TenantLedgerData.placeholder() => _TenantLedgerData(
    name: 'Priya Sharma', unitId: 'Room 07', billingMonth: 'October 2026',
    rentDuePaise: 550000, elecDuePaise: 135000, advanceBalancePaise: 1100000,
    entries: [
      _LedgerEntry(type: 'charge', subtype: 'rent', label: 'Rent charge', date: '01 Oct 2026', amountPaise: 550000, status: 'pending'),
      _LedgerEntry(type: 'charge', subtype: 'electricity', label: 'Electricity charge', date: '01 Oct 2026', amountPaise: 135000, status: 'pending'),
      _LedgerEntry(type: 'payment', label: 'Payment received', date: '02 Sep 2026', amountPaise: 648000, note: 'Cash'),
      _LedgerEntry(type: 'charge', subtype: 'rent', label: 'Rent charge', date: '01 Sep 2026', amountPaise: 550000, status: 'paid'),
      _LedgerEntry(type: 'charge', subtype: 'electricity', label: 'Electricity charge', date: '01 Sep 2026', amountPaise: 98000, status: 'paid'),
      _LedgerEntry(type: 'payment', label: 'Payment received', date: '05 Aug 2026', amountPaise: 648000, note: 'Online · UPI/8765432'),
      _LedgerEntry(type: 'charge', subtype: 'rent', label: 'Rent charge', date: '01 Aug 2026', amountPaise: 550000, status: 'paid'),
      _LedgerEntry(type: 'charge', subtype: 'electricity', label: 'Electricity charge', date: '01 Aug 2026', amountPaise: 98000, status: 'paid'),
    ],
  );
}

class _LedgerEntry {
  final String type, label, date;
  final String? subtype, status, note;
  final int amountPaise;

  const _LedgerEntry({
    required this.type, required this.label, required this.date,
    required this.amountPaise, this.subtype, this.status, this.note,
  });
}
