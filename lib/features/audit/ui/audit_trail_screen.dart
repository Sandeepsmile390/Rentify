import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/status_chip.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key, required this.tenancyId});
  final String tenancyId;

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  bool _isLoading = true;
  String _tenantName = '';
  String _unitId = '';
  List<_AuditEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch tenancy info
      final tRes = await client
          .from('tenancies')
          .select('tenant_name, unit_id, created_at, start_date')
          .eq('id', widget.tenancyId)
          .maybeSingle();

      if (tRes != null) {
        _tenantName = (tRes['tenant_name'] as String?) ?? 'Tenant';
        _unitId = (tRes['unit_id'] as String?) ?? '—';
      }

      final List<_AuditEvent> allEvents = [];

      // Add tenancy created event
      if (tRes != null && tRes['created_at'] != null) {
        allEvents.add(_AuditEvent(
          title: 'Tenancy Agreement Started',
          subtitle: 'Unit $_unitId · Effective ${tRes['start_date'] ?? 'start'}',
          timestamp: DateTime.tryParse(tRes['created_at'] as String) ?? DateTime.now(),
          icon: Icons.assignment_turned_in_rounded,
          color: AppColors.action,
        ));
      }

      // 2. Fetch payments
      final paymentsRes = await client
          .from('payments')
          .select('amount_paise, payment_date, method, reference, notes, created_at')
          .eq('tenancy_id', widget.tenancyId);

      for (final p in (paymentsRes as List<dynamic>)) {
        final amt = (p['amount_paise'] as num?)?.toInt() ?? 0;
        final method = (p['method'] as String?) ?? 'cash';
        final ref = p['reference'] as String?;
        final notes = p['notes'] as String?;
        final date = DateTime.tryParse((p['created_at'] as String?) ?? '') ??
            DateTime.tryParse((p['payment_date'] as String?) ?? '') ??
            DateTime.now();

        allEvents.add(_AuditEvent(
          title: 'Payment Recorded: ${CurrencyFormatter.fromPaise(amt)}',
          subtitle: 'Method: ${method.toUpperCase()}${ref != null ? ' · Ref: $ref' : ''}${notes != null ? ' · $notes' : ''}',
          timestamp: date,
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ));
      }

      // 3. Fetch meter readings
      final readingsRes = await client
          .from('meter_readings')
          .select('current_reading, previous_reading, units_consumed, amount_paise, billing_month, created_at')
          .eq('tenancy_id', widget.tenancyId);

      for (final m in (readingsRes as List<dynamic>)) {
        final units = m['units_consumed'] ?? 0;
        final curr = m['current_reading'] ?? 0;
        final prev = m['previous_reading'] ?? 0;
        final amt = (m['amount_paise'] as num?)?.toInt() ?? 0;
        final date = DateTime.tryParse((m['created_at'] as String?) ?? '') ?? DateTime.now();

        allEvents.add(_AuditEvent(
          title: 'Meter Reading: $curr kWh ($units units)',
          subtitle: 'Prev: $prev kWh · Electricity Charge: ${CurrencyFormatter.fromPaise(amt)}',
          timestamp: date,
          icon: Icons.electric_meter_rounded,
          color: AppColors.warning,
        ));
      }

      // 4. Fetch charges
      final chargesRes = await client
          .from('charges')
          .select('charge_type, billing_month, amount_paise, status, created_at')
          .eq('tenancy_id', widget.tenancyId);

      for (final c in (chargesRes as List<dynamic>)) {
        final type = (c['charge_type'] as String?) == 'electricity' ? 'Electricity Bill' : 'Rent Charge';
        final amt = (c['amount_paise'] as num?)?.toInt() ?? 0;
        final status = (c['status'] as String?) ?? 'pending';
        final date = DateTime.tryParse((c['created_at'] as String?) ?? '') ?? DateTime.now();

        allEvents.add(_AuditEvent(
          title: '$type: ${CurrencyFormatter.fromPaise(amt)}',
          subtitle: 'Month: ${c['billing_month'] ?? ''} · Status: ${status.toUpperCase()}',
          timestamp: date,
          icon: Icons.receipt_long_rounded,
          color: AppColors.navy,
        ));
      }

      // 5. Fetch advance transactions
      final advRes = await client
          .from('tenant_advances')
          .select('id')
          .eq('tenancy_id', widget.tenancyId)
          .maybeSingle();

      if (advRes != null) {
        final txnsRes = await client
            .from('advance_transactions')
            .select('txn_type, amount_paise, reason, created_at')
            .eq('advance_id', advRes['id'])
            .order('created_at', ascending: false);

        for (final a in (txnsRes as List<dynamic>)) {
          final amt = (a['amount_paise'] as num?)?.toInt() ?? 0;
          final type = (a['txn_type'] as String?) ?? 'received';
          final reason = a['reason'] as String?;
          final date = DateTime.tryParse((a['created_at'] as String?) ?? '') ?? DateTime.now();

          allEvents.add(_AuditEvent(
            title: 'Deposit ${type.toUpperCase()}: ${CurrencyFormatter.fromPaise(amt.abs())}',
            subtitle: reason ?? 'Advance ledger transaction',
            timestamp: date,
            icon: Icons.account_balance_wallet_rounded,
            color: amt >= 0 ? AppColors.action : AppColors.error,
          ));
        }
      }

      // Sort descending by timestamp
      allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _events = allEvents;
      });
    } catch (e) {
      debugPrint('Error loading audit trail: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Audit Trail', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAuditTrail();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header banner
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.actionBg,
                        child: Text(
                          _tenantName.isNotEmpty ? _tenantName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.action, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tenantName, style: AppTextStyles.bodyMedium),
                            Text('Unit: $_unitId · Complete activity log', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: '${_events.length} events',
                        type: StatusChipType.neutral,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Events timeline
                Expanded(
                  child: _events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.history_rounded, size: 48, color: AppColors.inkMuted),
                              const SizedBox(height: 12),
                              Text('No audit events yet', style: AppTextStyles.h3),
                              const SizedBox(height: 8),
                              Text('All tenancy actions will appear here in chronological order.',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final ev = _events[i];
                            return _EventCard(event: ev);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _AuditEvent {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const _AuditEvent({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  String get formattedTime {
    final d = timestamp;
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    final yr = d.year;
    final hr = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day/$mon/$yr $hr:$min';
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final _AuditEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: event.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(event.icon, size: 20, color: event.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      event.formattedTime,
                      style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.subtitle,
                  style: AppTextStyles.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
