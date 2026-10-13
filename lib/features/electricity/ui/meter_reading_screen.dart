import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/utilities/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// Figma frame 10 — Electricity meter reading entry (admin mobile)
class MeterReadingScreen extends ConsumerStatefulWidget {
  const MeterReadingScreen({super.key, required this.tenancyId});
  final String tenancyId;

  @override
  ConsumerState<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends ConsumerState<MeterReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentReadingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  double _previousReading = 0.0;
  final int _ratePaise = 900; // ₹9/unit
  String _tenantName = 'Tenant';
  String _unitId = '';
  String get _billingMonth => 'October 2026';

  @override
  void initState() {
    super.initState();
    _loadPreviousReading();
  }

  Future<void> _loadPreviousReading() async {
    try {
      final client = Supabase.instance.client;
      final tenancy = await client
          .from('tenancies')
          .select('tenant_name, unit_id')
          .eq('id', widget.tenancyId)
          .maybeSingle();

      if (tenancy != null && mounted) {
        setState(() {
          _tenantName = (tenancy['tenant_name'] as String?) ?? 'Tenant';
          _unitId = (tenancy['unit_id'] as String?) ?? '';
        });
      }

      final res = await client
          .from('meter_readings')
          .select('current_reading')
          .eq('tenancy_id', widget.tenancyId)
          .order('billing_month', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _previousReading = (res['current_reading'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _currentReadingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _currentReading =>
      double.tryParse(_currentReadingCtrl.text.trim()) ?? _previousReading;

  double get _unitsConsumed => (_currentReading - _previousReading).clamp(0, double.infinity);

  int get _chargeAmountPaise => (_unitsConsumed * _ratePaise).round();

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final now = DateTime.now();
      final billingMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

      await client.from('meter_readings').insert({
        'tenancy_id': widget.tenancyId,
        'billing_month': billingMonth,
        'previous_reading': _previousReading,
        'current_reading': _currentReading,
        'rate_paise': _ratePaise,
        'amount_paise': _chargeAmountPaise,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        if (userId != null) 'created_by': userId,
      });

      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save reading: $e');
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
              Text('Reading saved!', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                '${_unitsConsumed.toStringAsFixed(1)} units · ${CurrencyFormatter.fromPaise(_chargeAmountPaise)} charged',
                style: AppTextStyles.bodyRegular,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(sheetCtx, rootNavigator: true).pop();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Meter reading', style: AppTextStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
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
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.electric_meter_outlined, color: Colors.white70, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$_tenantName${_unitId.isNotEmpty ? ' · $_unitId' : ''}', style: AppTextStyles.h3.copyWith(color: Colors.white)),
                      Text(_billingMonth, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Previous reading', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(
                      '${_previousReading.toStringAsFixed(1)} units',
                      style: AppTextStyles.currencyMedium.copyWith(color: AppColors.ink),
                    ),
                    Text('September 2026', style: AppTextStyles.caption),
                  ]),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.inkMuted),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Rate', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyFormatter.fromPaise(_ratePaise)}/unit',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ]),
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
                        Text('Charge for this month', style: AppTextStyles.bodyMedium),
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
              hint: 'e.g. meter was replaced, estimate due to access issue…',
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
                        'Unusually high consumption: ${_unitsConsumed.toStringAsFixed(0)} units. Please double-check the reading.',
                        style: AppTextStyles.bodyRegular.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
