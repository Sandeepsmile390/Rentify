import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/routes.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/utilities/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// Figma frame 04 — Record payment (mobile admin)
class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, required this.tenancyId});
  final String tenancyId;

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  String _method = 'cash';
  bool _isSubmitting = false;
  String? _errorMessage;
  DateTime _paymentDate = DateTime.now();
  bool _showAllocations = true;
  String _tenantName = '';
  String _unitId = '';
  int _totalOutstandingPaise = 0;

  List<_PendingCharge> _charges = [];
  final Map<String, int> _allocations = {}; // chargeId → paise to allocate

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = _formatDate(_paymentDate);
    _loadCharges();
  }

  Future<void> _loadCharges() async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch tenancy details
      final tenRes = await client
          .from('tenancies')
          .select('tenant_name, unit_id')
          .eq('id', widget.tenancyId)
          .maybeSingle();

      if (tenRes != null) {
        _tenantName = (tenRes['tenant_name'] as String?) ?? '';
        _unitId = (tenRes['unit_id'] as String?) ?? '';
      }

      // 2. Fetch pending charges
      final res = await client
          .from('charges')
          .select('id, charge_type, amount_paise, billing_month, status')
          .eq('tenancy_id', widget.tenancyId)
          .neq('status', 'paid');

      if (!mounted) return;
      final rows = res as List<dynamic>;
      final list = rows.map((r) => _PendingCharge(
            id: r['id'] as String,
            label: (r['charge_type'] as String?) == 'electricity' ? 'Electricity' : 'Rent',
            month: (r['billing_month'] as String?) ?? 'Current',
            amountPaise: (r['amount_paise'] as num?)?.toInt() ?? 0,
            outstandingPaise: (r['amount_paise'] as num?)?.toInt() ?? 0,
            type: (r['charge_type'] as String?) ?? 'rent',
          )).toList();

      setState(() {
        _charges = list;
        _totalOutstandingPaise = list.fold(0, (sum, c) => sum + c.outstandingPaise);
        for (final c in list) {
          _allocations[c.id] = c.outstandingPaise;
        }
      });
    } catch (e) {
      debugPrint('Error loading charges: $e');
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select payment date',
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
        _dateCtrl.text = _formatDate(picked);
      });
    }
  }

  int get _totalAllocated =>
      _allocations.values.fold(0, (s, v) => s + v);

  int get _paymentAmountPaise =>
      CurrencyFormatter.toPaise(_amountCtrl.text) ?? 0;

  bool get _allocationExceedsPayment =>
      _totalAllocated > _paymentAmountPaise && _paymentAmountPaise > 0;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_allocationExceedsPayment) {
      setState(() => _errorMessage = 'Allocated amount (${CurrencyFormatter.fromPaise(_totalAllocated)}) exceeds the payment amount.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final paymentRow = await client.from('payments').insert({
        'tenancy_id': widget.tenancyId,
        'amount_paise': _paymentAmountPaise,
        'method': _method,
        'payment_date': _paymentDate.toIso8601String().substring(0, 10),
        'reference': _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        if (userId != null) 'recorded_by': userId,
      }).select().single();

      final paymentId = paymentRow['id'] as String;

      // Insert allocations if any charges were allocated
      final validAllocations = _allocations.entries
          .where((e) => e.value > 0)
          .toList();

      if (validAllocations.isNotEmpty) {
        final allocRows = validAllocations.map((e) => {
          'payment_id': paymentId,
          'charge_id': e.key,
          'amount_paise': e.value,
          if (userId != null) 'created_by': userId,
        }).toList();

        await client.from('payment_allocations').insert(allocRows);

        // Update charge status if fully paid or partial
        for (final entry in validAllocations) {
          final chargeMatch = _charges.where((c) => c.id == entry.key);
          if (chargeMatch.isNotEmpty) {
            final charge = chargeMatch.first;
            final newStatus = entry.value >= charge.outstandingPaise ? 'paid' : 'partial';
            await client.from('charges').update({'status': newStatus}).eq('id', entry.key);
          }
        }
      }

      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to record payment: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Payment recorded!', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                '${CurrencyFormatter.fromPaise(_paymentAmountPaise)} has been recorded against this account.',
                style: AppTextStyles.bodyRegular,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: 'Done',
                    type: AppButtonType.primary,
                    onPressed: () {
                      Navigator.of(sheetCtx, rootNavigator: true).pop();
                      if (mounted) _navigateBack();
                    },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('${Routes.tenantProfile}/${widget.tenancyId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Record payment', style: AppTextStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _navigateBack,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Tenant header ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tenant', style: AppTextStyles.caption.copyWith(color: Colors.white54)),
                  const SizedBox(height: 4),
                  Text(
                    _tenantName.isNotEmpty ? _tenantName : 'Tenant',
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                  Text(
                    '${_unitId.isNotEmpty ? '$_unitId · ' : ''}${CurrencyFormatter.fromPaise(_totalOutstandingPaise)} total outstanding',
                    style: AppTextStyles.caption.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Payment amount ────────────────────────────────
            AppTextField(
              label: 'Payment amount (₹) *',
              hint: '0',
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.currency_rupee_rounded,
              validator: Validators.positiveAmount,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            // ── Date ──────────────────────────────────────────
            AppTextField(
              label: 'Payment date *',
              hint: 'DD/MM/YYYY',
              controller: _dateCtrl,
              readOnly: true,
              prefixIcon: Icons.calendar_today_outlined,
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                onPressed: _pickDate,
              ),
              validator: Validators.date,
            ),
            const SizedBox(height: 14),

            // ── Method ────────────────────────────────────────
            Text('Payment method *', style: AppTextStyles.inputLabel),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money_rounded)),
                ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.smartphone_rounded)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 14),

            if (_method == 'online') ...[
              AppTextField(
                label: 'Reference / UPI ID',
                hint: 'e.g. UPI/1234567890',
                controller: _referenceCtrl,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.tag_rounded,
              ),
              const SizedBox(height: 14),
            ],

            // ── Notes ─────────────────────────────────────────
            AppTextField(
              label: 'Notes (optional)',
              hint: 'Any remarks…',
              controller: _notesCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── Allocations ───────────────────────────────────
            Row(
              children: [
                Text('Allocate to charges', style: AppTextStyles.h3),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _showAllocations = !_showAllocations),
                  child: Text(_showAllocations ? 'Hide' : 'Show'),
                ),
              ],
            ),
            if (_showAllocations) ...[
              const SizedBox(height: 8),
              ..._charges.map((c) => _AllocationRow(
                charge: c,
                allocated: _allocations[c.id] ?? 0,
                onChanged: (v) => setState(() => _allocations[c.id] = v),
              )),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total allocated', style: AppTextStyles.bodyMedium),
                  Text(
                    CurrencyFormatter.fromPaise(_totalAllocated),
                    style: AppTextStyles.currencySmall.copyWith(
                      color: _allocationExceedsPayment ? AppColors.error : AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (_paymentAmountPaise > _totalAllocated) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Unallocated balance', style: AppTextStyles.caption),
                    Text(
                      CurrencyFormatter.fromPaise(_paymentAmountPaise - _totalAllocated),
                      style: AppTextStyles.captionBold.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 24),

            // ── Error ─────────────────────────────────────────
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorBorder),
                ),
                child: Text(_errorMessage!, style: AppTextStyles.bodyRegular.copyWith(color: AppColors.error)),
              ),
              const SizedBox(height: 16),
            ],

            AppButton(
              label: 'Record payment',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Allocation row ────────────────────────────────────────────────

class _AllocationRow extends StatefulWidget {
  const _AllocationRow({
    required this.charge,
    required this.allocated,
    required this.onChanged,
  });
  final _PendingCharge charge;
  final int allocated;
  final ValueChanged<int> onChanged;

  @override
  State<_AllocationRow> createState() => _AllocationRowState();
}

class _AllocationRowState extends State<_AllocationRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: (widget.allocated / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
          Icon(
            widget.charge.type == 'rent'
                ? Icons.home_outlined
                : Icons.bolt_rounded,
            size: 18,
            color: widget.charge.type == 'rent'
                ? AppColors.action
                : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.charge.label, style: AppTextStyles.bodyMedium),
              Text(
                '${widget.charge.month} · Outstanding: ${CurrencyFormatter.fromPaise(widget.charge.outstandingPaise)}',
                style: AppTextStyles.caption,
              ),
            ]),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                prefixText: '₹',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                widget.onChanged(parsed * 100); // input in rupees, store paise
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCharge {
  final String id, label, month, type;
  final int amountPaise, outstandingPaise;
  const _PendingCharge({
    required this.id, required this.label, required this.month,
    required this.type, required this.amountPaise, required this.outstandingPaise,
  });
}
