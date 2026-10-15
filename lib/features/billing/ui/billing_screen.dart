import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('billing_runs')
          .select('*')
          .order('billing_month', ascending: false);

      final rows = res as List<dynamic>;
      if (rows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _runs = [];
        });
        return;
      }

      final list = rows.map((r) {
        final monthStr = (r['billing_month'] as String?) ?? '';
        final status = (r['status'] as String?) ?? 'completed';
        final count = (r['charges_created'] as num?)?.toInt() ?? 0;
        final started = (r['created_at'] as String?) ?? 'Recent';

        return _BillingRun(
          month: monthStr,
          status: status,
          rentCharges: count,
          elecCharges: 0,
          totalAmountPaise: 0,
          startedAt: started,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _runs = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _runs = [];
      });
    }
  }

  Future<void> _runBilling() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Run billing?', style: AppTextStyles.h2),
        content: Text(
          'This will generate rent and electricity charges for all active '
          'tenancies for the current month. Charges already generated will '
          'not be duplicated (idempotent).',
          style: AppTextStyles.bodyRegular,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(true),
              child: const Text('Run billing')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRunning = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final now = DateTime.now();
      final billingMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

      // 1. Fetch active tenancies
      final tenancies = await client
          .from('tenancies')
          .select('id')
          .eq('is_active', true);

      int chargesCreated = 0;
      int rentCount = 0;
      int elecCount = 0;
      int totalPaise = 0;

      for (final t in (tenancies as List<dynamic>)) {
        final tId = t['id'] as String;

        // Fetch rent rate
        final rentRes = await client
            .from('rent_rates')
            .select('amount_paise')
            .eq('tenancy_id', tId)
            .order('effective_from', ascending: false)
            .limit(1)
            .maybeSingle();

        if (rentRes != null) {
          final amt = (rentRes['amount_paise'] as num?)?.toInt() ?? 0;
          if (amt > 0) {
            await client.from('charges').upsert({
              'tenancy_id': tId,
              'charge_type': 'rent',
              'billing_month': billingMonth,
              'amount_paise': amt,
              'status': 'pending',
              if (userId != null) 'created_by': userId,
            }, onConflict: 'tenancy_id,charge_type,billing_month');
            chargesCreated++;
            rentCount++;
            totalPaise += amt;
          }
        }

        // Fetch fixed electricity if applicable
        final elecRes = await client
            .from('electricity_config')
            .select('mode, fixed_amount_paise')
            .eq('tenancy_id', tId)
            .maybeSingle();

        if (elecRes != null && elecRes['mode'] == 'fixed') {
          final fixedAmt = (elecRes['fixed_amount_paise'] as num?)?.toInt() ?? 0;
          if (fixedAmt > 0) {
            await client.from('charges').upsert({
              'tenancy_id': tId,
              'charge_type': 'electricity',
              'billing_month': billingMonth,
              'amount_paise': fixedAmt,
              'status': 'pending',
              if (userId != null) 'created_by': userId,
            }, onConflict: 'tenancy_id,charge_type,billing_month');
            chargesCreated++;
            elecCount++;
            totalPaise += fixedAmt;
          }
        }
      }

      // Record billing run
      await client.from('billing_runs').insert({
        'billing_month': billingMonth,
        'status': 'completed',
        'charges_created': chargesCreated,
        'completed_at': DateTime.now().toIso8601String(),
        if (userId != null) 'triggered_by': userId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Billing run complete: $chargesCreated charges generated ($rentCount rent, $elecCount electricity - ${CurrencyFormatter.fromPaise(totalPaise)})'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Billing run error: $e'),
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
}
