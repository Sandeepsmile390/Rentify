import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/status_chip.dart';

/// Billing run status screen — shows monthly billing run history
/// and lets admin trigger a manual run.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  bool _isLoading = true;
  bool _isRunning = false;
  List<_BillingRun> _runs = [];

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
      _runs = _BillingRun.placeholders();
    });
  }

  Future<void> _runBilling() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Run billing?', style: AppTextStyles.h2),
        content: Text(
          'This will generate rent and electricity charges for all active '
          'tenancies for the current month. Charges already generated will '
          'not be duplicated (idempotent).',
          style: AppTextStyles.bodyRegular,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run billing')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRunning = true);
    try {
      // TODO: call run-billing Edge Function
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _runs.insert(
          0,
          _BillingRun(
            month: 'October 2026',
            status: 'completed',
            rentCharges: 28,
            elecCharges: 24,
            totalAmountPaise: 18500000,
            startedAt: 'Just now',
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Billing run completed successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Billing run failed — check Edge Function logs'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Billing runs', style: AppTextStyles.h2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  color: AppColors.actionBg,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.action, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Monthly billing runs automatically on the 1st of each month. '
                          'Use the button below to run manually.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.action),
                        ),
                      ),
                    ],
                  ),
                ),

                // Run list
                Expanded(
                  child: _runs.isEmpty
                      ? const Center(child: Text('No billing runs yet'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _runs.length,
                          itemBuilder: (_, i) => _RunCard(run: _runs[i]),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isRunning ? null : _runBilling,
            icon: _isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.run_circle_outlined),
            label: Text(_isRunning ? 'Running…' : 'Run billing now'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});
  final _BillingRun run;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Text(run.month, style: AppTextStyles.h3),
              StatusChip(
                label: _label(run.status),
                type: _chipType(run.status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            _Stat('Rent charges', run.rentCharges.toString()),
            const SizedBox(width: 24),
            _Stat('Elec charges', run.elecCharges.toString()),
            const SizedBox(width: 24),
            _Stat('Total', CurrencyFormatter.fromPaise(run.totalAmountPaise)),
          ]),
          const SizedBox(height: 8),
          Text(run.startedAt,
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
        ],
      ),
    );
  }

  String _label(String s) => switch (s) {
        'completed' => 'Completed',
        'running' => 'Running',
        'failed' => 'Failed',
        _ => s,
      };

  StatusChipType _chipType(String s) => switch (s) {
        'completed' => StatusChipType.success,
        'running' => StatusChipType.warning,
        'failed' => StatusChipType.error,
        _ => StatusChipType.neutral,
      };
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      );
}

class _BillingRun {
  final String month, status, startedAt;
  final int rentCharges, elecCharges, totalAmountPaise;

  const _BillingRun({
    required this.month,
    required this.status,
    required this.rentCharges,
    required this.elecCharges,
    required this.totalAmountPaise,
    required this.startedAt,
  });

  static List<_BillingRun> placeholders() => [
        _BillingRun(
            month: 'September 2026',
            status: 'completed',
            rentCharges: 28,
            elecCharges: 26,
            totalAmountPaise: 17800000,
            startedAt: '01 Sep 2026, 12:00 AM'),
        _BillingRun(
            month: 'August 2026',
            status: 'completed',
            rentCharges: 27,
            elecCharges: 25,
            totalAmountPaise: 17200000,
            startedAt: '01 Aug 2026, 12:00 AM'),
      ];
}
