import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';

/// Reports screen — monthly summary + per-tenant breakdown
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedMonth = 'Oct 2026';
  bool _isLoading = true;
  _ReportData? _data;

  final List<String> _months = [
    'Oct 2026', 'Sep 2026', 'Aug 2026', 'Jul 2026',
    'Jun 2026', 'May 2026', 'Apr 2026', 'Mar 2026',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _data = _ReportData.placeholder(_selectedMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Reports', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export feature coming soon')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text('Month:', style: AppTextStyles.bodyMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _months.length,
                      itemBuilder: (_, i) {
                        final m = _months[i];
                        final isSelected = m == _selectedMonth;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedMonth = m);
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
                            child: Text(
                              m,
                              style: AppTextStyles.captionBold.copyWith(
                                color: isSelected ? Colors.white : AppColors.inkMuted,
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
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary cards
                      _SummaryRow(data: _data!),
                      const SizedBox(height: 20),

                      // Collection rate
                      _CollectionRate(data: _data!),
                      const SizedBox(height: 20),

                      // Per-tenant table
                      Text('Per-tenant breakdown', style: AppTextStyles.h3),
                      const SizedBox(height: 12),
                      ..._data!.rows.map((r) => _ReportRow(row: r)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});
  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Total charged',
          value: CurrencyFormatter.fromPaise(data.totalChargedPaise),
          icon: Icons.receipt_outlined,
          color: AppColors.action,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: 'Total collected',
          value: CurrencyFormatter.fromPaise(data.totalCollectedPaise),
          icon: Icons.payments_outlined,
          color: AppColors.success,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          label: 'Outstanding',
          value: CurrencyFormatter.fromPaise(data.outstandingPaise),
          icon: Icons.account_balance_wallet_outlined,
          color: data.outstandingPaise > 0 ? AppColors.amountDue : AppColors.success,
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
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
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.currencySmall.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _CollectionRate extends StatelessWidget {
  const _CollectionRate({required this.data});
  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final rate = data.totalChargedPaise > 0
        ? (data.totalCollectedPaise / data.totalChargedPaise).clamp(0.0, 1.0)
        : 0.0;
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
              Text('Collection rate', style: AppTextStyles.h3),
              Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.currencyMedium.copyWith(
                  color: rate > 0.8 ? AppColors.success : rate > 0.5 ? AppColors.warning : AppColors.error,
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
                rate > 0.8 ? AppColors.success : rate > 0.5 ? AppColors.warning : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${data.paidCount} of ${data.totalTenants} tenants paid', style: AppTextStyles.caption),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.name, style: AppTextStyles.bodyMedium),
              Text(row.unit, style: AppTextStyles.caption),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.fromPaise(row.chargedPaise),
              style: AppTextStyles.currencySmall,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.fromPaise(row.collectedPaise),
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
        ],
      ),
    );
  }
}

// Data
class _ReportData {
  final String month;
  final int totalChargedPaise, totalCollectedPaise, outstandingPaise;
  final int paidCount, totalTenants;
  final List<_ReportRowData> rows;

  const _ReportData({
    required this.month, required this.totalChargedPaise,
    required this.totalCollectedPaise, required this.outstandingPaise,
    required this.paidCount, required this.totalTenants, required this.rows,
  });

  factory _ReportData.placeholder(String month) => _ReportData(
    month: month,
    totalChargedPaise: 18500000, totalCollectedPaise: 13200000,
    outstandingPaise: 5300000, paidCount: 22, totalTenants: 28,
    rows: [
      _ReportRowData(name: 'Manoj Kumar', unit: 'Room 03', chargedPaise: 550000, collectedPaise: 550000),
      _ReportRowData(name: 'Priya Sharma', unit: 'Room 07', chargedPaise: 685000, collectedPaise: 0),
      _ReportRowData(name: 'Ramesh Traders', unit: 'Shop A', chargedPaise: 800000, collectedPaise: 800000),
      _ReportRowData(name: 'Vikram Singh', unit: 'Room 12', chargedPaise: 540000, collectedPaise: 0),
    ],
  );
}

class _ReportRowData {
  final String name, unit;
  final int chargedPaise, collectedPaise;
  const _ReportRowData({required this.name, required this.unit, required this.chargedPaise, required this.collectedPaise});
  int get outstandingPaise => chargedPaise - collectedPaise;
}
