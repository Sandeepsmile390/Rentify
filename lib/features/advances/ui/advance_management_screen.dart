import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_chip.dart';

/// Figma frame 11 — Advance / Security deposit management
class AdvanceManagementScreen extends ConsumerStatefulWidget {
  const AdvanceManagementScreen({super.key, required this.tenancyId});
  final String tenancyId;

  @override
  ConsumerState<AdvanceManagementScreen> createState() =>
      _AdvanceManagementScreenState();
}

class _AdvanceManagementScreenState
    extends ConsumerState<AdvanceManagementScreen> {
  bool _isLoading = true;
  _AdvanceData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _data = _AdvanceData.placeholder();
    });
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _AddTransactionSheet(
          onSubmit: (type, amountPaise, reason) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${type == 'received' ? 'Deposit received' : 'Transaction recorded'}: ${CurrencyFormatter.fromPaise(amountPaise)}',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Advance & Deposit', style: AppTextStyles.h2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance header
                _BalanceHeader(data: _data!),
                // Transaction list
                Expanded(
                  child: _data!.transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined,
                                  size: 48, color: AppColors.inkMuted),
                              const SizedBox(height: 12),
                              Text('No transactions yet',
                                  style: AppTextStyles.h3),
                              const SizedBox(height: 8),
                              Text('Record the first advance deposit',
                                  style: AppTextStyles.bodyRegular),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _data!.transactions.length,
                          itemBuilder: (_, i) =>
                              _TransactionTile(txn: _data!.transactions[i]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add transaction'),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.data});
  final _AdvanceData data;

  @override
  Widget build(BuildContext context) {
    final isPositive = data.balancePaise >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: AppColors.navy,
      child: Column(
        children: [
          Text('Current balance',
              style: AppTextStyles.caption.copyWith(color: Colors.white60)),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.fromPaise(data.balancePaise.abs()),
            style: AppTextStyles.currencyLarge.copyWith(
              color: isPositive ? Colors.white : AppColors.errorLight,
            ),
          ),
          const SizedBox(height: 4),
          if (!isPositive)
            Text(
              'Deficit — tenant owes advance',
              style: AppTextStyles.caption.copyWith(color: AppColors.errorLight),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BalanceStat(
                  label: 'Total received',
                  value: CurrencyFormatter.fromPaise(data.totalReceivedPaise),
                  color: AppColors.successLight),
              const SizedBox(width: 24),
              _BalanceStat(
                  label: 'Total applied',
                  value: CurrencyFormatter.fromPaise(data.totalAppliedPaise),
                  color: AppColors.warningLight),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(color: Colors.white54)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(color: color)),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});
  final _AdvanceTxn txn;

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.amountPaise > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.successBg : AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: isCredit ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.label, style: AppTextStyles.bodyMedium),
                  Text(txn.date,
                      style: AppTextStyles.caption),
                  if (txn.reason != null)
                    Text(txn.reason!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.inkMuted)),
                ]),
          ),
          Text(
            isCredit
                ? '+${CurrencyFormatter.fromPaise(txn.amountPaise)}'
                : CurrencyFormatter.fromPaise(txn.amountPaise.abs()),
            style: AppTextStyles.currencySmall.copyWith(
              color:
                  isCredit ? AppColors.amountPositive : AppColors.amountDue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet({required this.onSubmit});
  final void Function(String type, int amountPaise, String? reason) onSubmit;

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _type = 'received';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record transaction', style: AppTextStyles.h2),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'received',
                  label: Text('Received'),
                  icon: Icon(Icons.arrow_downward_rounded)),
              ButtonSegment(
                  value: 'refunded',
                  label: Text('Refunded'),
                  icon: Icon(Icons.arrow_upward_rounded)),
              ButtonSegment(
                  value: 'adjusted',
                  label: Text('Adjusted'),
                  icon: Icon(Icons.swap_horiz_rounded)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Save',
            onPressed: () {
              final paise = (double.tryParse(_amountCtrl.text) ?? 0) * 100;
              if (paise > 0) {
                widget.onSubmit(_type, paise.round(), _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Data
class _AdvanceData {
  final int balancePaise, totalReceivedPaise, totalAppliedPaise;
  final List<_AdvanceTxn> transactions;
  const _AdvanceData({required this.balancePaise, required this.totalReceivedPaise, required this.totalAppliedPaise, required this.transactions});

  factory _AdvanceData.placeholder() => _AdvanceData(
    balancePaise: 1100000, totalReceivedPaise: 1100000, totalAppliedPaise: 0,
    transactions: [
      _AdvanceTxn(label: 'Security deposit received', date: '01 Jan 2025', amountPaise: 1100000, reason: 'Initial deposit at tenancy start'),
    ],
  );
}

class _AdvanceTxn {
  final String label, date;
  final int amountPaise;
  final String? reason;
  const _AdvanceTxn({required this.label, required this.date, required this.amountPaise, this.reason});
}
