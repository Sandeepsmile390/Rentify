import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/utilities/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// Figma frame 10 — Electricity meter reading entry (admin mobile & web)
class MeterReadingScreen extends ConsumerStatefulWidget {
  const MeterReadingScreen({
    super.key,
    required this.tenancyId,
    this.initialBillingMonth,
  });

  final String tenancyId;
  final String? initialBillingMonth; // YYYY-MM-01 format

  @override
  ConsumerState<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends ConsumerState<MeterReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentReadingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  double _previousReading = 0.0;
  String _previousReadingMonth = '';
  int _ratePaise = 900; // Default ₹9.00/unit
  String _tenantName = 'Tenant';
  String _unitId = '';
  
  late String _selectedBillingMonth; // Canonical format: YYYY-MM-01
  final List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedBillingMonth = widget.initialBillingMonth ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    // Populate the last 6 canonical billing months for convenient period selection
    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final mKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-01';
      _availableMonths.add(mKey);
    }
    if (!_availableMonths.contains(_selectedBillingMonth)) {
      _availableMonths.insert(0, _selectedBillingMonth);
    }

    _loadData();
  }

  String _formatMonthLabel(String canonicalMonth) {
    try {
      final parts = canonicalMonth.split('-');
      if (parts.length >= 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return DateFormat('MMMM yyyy').format(dt);
      }
    } catch (_) {}
    return canonicalMonth;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Tenancy info
      final tenancy = await client
          .from('tenancies')
          .select('tenant_name, unit_id')
          .eq('id', widget.tenancyId)
          .maybeSingle();

      if (tenancy != null && mounted) {
        _tenantName = (tenancy['tenant_name'] as String?) ?? 'Tenant';
        _unitId = (tenancy['unit_id'] as String?) ?? '';
      }

      // 2. Effective electricity rate for this billing month
      try {
        final rateRes = await client
            .from('electricity_rates')
            .select('rate_paise')
            .lte('effective_from', _selectedBillingMonth)
            .order('effective_from', ascending: false)
            .limit(1)
            .maybeSingle();

        if (rateRes != null && rateRes['rate_paise'] != null) {
          _ratePaise = (rateRes['rate_paise'] as num).toInt();
        }
      } catch (_) {}

      // 3. Baseline / Previous accepted reading strictly BEFORE this billing month
      double baseline = 0.0;
      String baselineMonthLabel = 'Initial config';

      final prevReadingRes = await client
          .from('meter_readings')
          .select('current_reading, billing_month')
          .eq('tenancy_id', widget.tenancyId)
          .eq('is_corrected', false)
          .lt('billing_month', _selectedBillingMonth)
          .order('billing_month', ascending: false)
          .limit(1)
          .maybeSingle();

      if (prevReadingRes != null) {
        baseline = (prevReadingRes['current_reading'] as num?)?.toDouble() ?? 0.0;
        baselineMonthLabel = _formatMonthLabel((prevReadingRes['billing_month'] as String?) ?? '');
      } else {
        // Fall back to configured initial_reading on electricity_config
        final configRes = await client
            .from('electricity_config')
            .select('initial_reading')
            .eq('tenancy_id', widget.tenancyId)
            .maybeSingle();
        if (configRes != null && configRes['initial_reading'] != null) {
          baseline = (configRes['initial_reading'] as num).toDouble();
          baselineMonthLabel = 'Initial reading baseline';
        }
      }

      _previousReading = baseline;
      _previousReadingMonth = baselineMonthLabel;

      // 4. Check if an existing reading already exists for THIS selected month
      final currentMonthReading = await client
          .from('meter_readings')
          .select('current_reading, notes')
          .eq('tenancy_id', widget.tenancyId)
          .eq('billing_month', _selectedBillingMonth)
          .eq('is_corrected', false)
          .maybeSingle();

      if (currentMonthReading != null) {
        final readingVal = (currentMonthReading['current_reading'] as num?)?.toDouble();
        if (readingVal != null) {
          _currentReadingCtrl.text = readingVal.toStringAsFixed(1);
        }
        final notesVal = currentMonthReading['notes'] as String?;
        if (notesVal != null && notesVal.isNotEmpty) {
          _notesCtrl.text = notesVal;
        }
      } else {
        _currentReadingCtrl.clear();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading meter reading context: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentReadingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _currentReading =>
      double.tryParse(_currentReadingCtrl.text.trim()) ?? _previousReading;

  double get _unitsConsumed =>
      (_currentReading - _previousReading).clamp(0, double.infinity);

  int get _chargeAmountPaise => (_unitsConsumed * _ratePaise).round();

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // 1. Atomically upsert meter_readings record
      final readingRow = await client.from('meter_readings').upsert({
        'tenancy_id': widget.tenancyId,
        'billing_month': _selectedBillingMonth,
        'previous_reading': _previousReading,
        'current_reading': _currentReading,
        'rate_paise': _ratePaise,
        'amount_paise': _chargeAmountPaise,
        'is_corrected': false,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        if (userId != null) 'created_by': userId,
      }, onConflict: 'tenancy_id,billing_month').select().single();

      final readingId = readingRow['id'] as String?;

      // 2. Reconcile corresponding electricity charge for that billing month
      // Check existing charge status and allocations to preserve financial integrity
      final existingCharge = await client
          .from('charges')
          .select('id, amount_paise, status')
          .eq('tenancy_id', widget.tenancyId)
          .eq('charge_type', 'electricity')
          .eq('billing_month', _selectedBillingMonth)
          .maybeSingle();

      if (existingCharge == null) {
        // Create new charge record immediately even if billing run already ran
        await client.from('charges').insert({
          'tenancy_id': widget.tenancyId,
          'charge_type': 'electricity',
          'billing_month': _selectedBillingMonth,
          'amount_paise': _chargeAmountPaise,
          'status': _chargeAmountPaise == 0 ? 'paid' : 'pending',
          if (readingId != null) 'meter_reading_id': readingId,
          if (userId != null) 'created_by': userId,
        });
      } else {
        final existingStatus = existingCharge['status'] as String?;
        // If pending, update amount and meter reading linkage
        if (existingStatus == 'pending') {
          await client.from('charges').update({
            'amount_paise': _chargeAmountPaise,
            'status': _chargeAmountPaise == 0 ? 'paid' : 'pending',
            if (readingId != null) 'meter_reading_id': readingId,
          }).eq('id', existingCharge['id']);
        }
      }

      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to save reading: $e');
      }
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Reading saved!', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                '${_unitsConsumed.toStringAsFixed(1)} units · ${CurrencyFormatter.fromPaise(_chargeAmountPaise)} charged for ${_formatMonthLabel(_selectedBillingMonth)}',
                style: AppTextStyles.bodyRegular,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  if (mounted) _navigateBack(didUpdate: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBack({bool didUpdate = false}) {
    if (context.canPop()) {
      context.pop(didUpdate);
    } else {
      context.go('${Routes.tenantProfile}/${widget.tenancyId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final billingMonthLabel = _formatMonthLabel(_selectedBillingMonth);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Meter reading', style: AppTextStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _navigateBack(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Tenant + billing period header ────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.electric_meter_outlined,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_tenantName${_unitId.isNotEmpty ? ' · $_unitId' : ''}',
                                style: AppTextStyles.h3.copyWith(color: Colors.white),
                              ),
                              Text(
                                billingMonthLabel,
                                style: AppTextStyles.caption.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Billing month selector ────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.inkMuted),
                        const SizedBox(width: 10),
                        Text('Billing Period:', style: AppTextStyles.bodyMedium),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBillingMonth,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              items: _availableMonths.map((m) {
                                return DropdownMenuItem<String>(
                                  value: m,
                                  child: Text(_formatMonthLabel(m), style: AppTextStyles.bodyMedium),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _selectedBillingMonth) {
                                  setState(() => _selectedBillingMonth = val);
                                  _loadData();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Previous reading display ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Previous reading baseline', style: AppTextStyles.caption),
                            const SizedBox(height: 4),
                            Text(
                              '${_previousReading.toStringAsFixed(1)} units',
                              style: AppTextStyles.currencyMedium.copyWith(color: AppColors.ink),
                            ),
                            Text(_previousReadingMonth, style: AppTextStyles.caption),
                          ],
                        ),
                        Icon(Icons.arrow_forward_rounded, color: AppColors.inkMuted),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Effective Rate', style: AppTextStyles.caption),
                            const SizedBox(height: 4),
                            Text(
                              '${CurrencyFormatter.fromPaise(_ratePaise)}/unit',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Current reading input ─────────────────────────
                  AppTextField(
                    label: 'Current reading *',
                    hint: _previousReading.toStringAsFixed(1),
                    controller: _currentReadingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.speed_rounded,
                    autofocus: true,
                    validator: (v) => Validators.meterReading(v, previousReading: _previousReading),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // ── Live calculation preview ──────────────────────
                  AnimatedOpacity(
                    opacity: _currentReadingCtrl.text.isNotEmpty ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.actionBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.actionBorder),
                      ),
                      child: Column(
                        children: [
                          _CalcRow('Units consumed', '${_unitsConsumed.toStringAsFixed(1)} units'),
                          const Divider(height: 20),
                          _CalcRow('Rate', '${CurrencyFormatter.fromPaise(_ratePaise)}/unit'),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Charge for $billingMonthLabel', style: AppTextStyles.bodyMedium),
                              Text(
                                CurrencyFormatter.fromPaise(_chargeAmountPaise),
                                style: AppTextStyles.currencyMedium.copyWith(color: AppColors.action),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Notes ─────────────────────────────────────────
                  AppTextField(
                    label: 'Notes (optional)',
                    hint: 'e.g. meter checked, reading confirmed…',
                    controller: _notesCtrl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // ── Warning if reading seems high ─────────────────
                  if (_unitsConsumed > 500) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warningBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'High consumption: ${_unitsConsumed.toStringAsFixed(0)} units. Please verify before saving.',
                              style: AppTextStyles.bodyRegular.copyWith(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Error banner ──────────────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.errorBorder),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodyRegular.copyWith(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  AppButton(
                    label: 'Save reading',
                    onPressed: _isSubmitting ? null : _submit,
                    isLoading: _isSubmitting,
                    icon: Icons.save_outlined,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyRegular),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}
