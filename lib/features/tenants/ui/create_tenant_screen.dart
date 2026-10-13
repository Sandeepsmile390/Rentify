import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/utilities/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// Figma frame 08 — Create tenant (mobile admin)
class CreateTenantScreen extends ConsumerStatefulWidget {
  const CreateTenantScreen({super.key});

  @override
  ConsumerState<CreateTenantScreen> createState() => _CreateTenantScreenState();
}

class _CreateTenantScreenState extends ConsumerState<CreateTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _fixedElecCtrl = TextEditingController();
  final _initialReadingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _tenantType = 'room';
  String _elecMode = 'meter';
  bool _createLogin = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startDateCtrl.text = _formatDate(_startDate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _mobileCtrl.dispose(); _emailCtrl.dispose();
    _unitCtrl.dispose(); _rentCtrl.dispose(); _startDateCtrl.dispose();
    _fixedElecCtrl.dispose(); _initialReadingCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select tenancy start date',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_createLogin && _emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Email is required when creating a login account.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      // TODO: Replace with actual Edge Function call via repository
      await Future.delayed(const Duration(seconds: 1)); // simulate API call

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create tenant. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.successBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 28),
        ),
        title: Text('Tenant added!', style: AppTextStyles.h2),
        content: Text(
          '${_nameCtrl.text.trim()} has been added to ${_unitCtrl.text.trim()}.',
          style: AppTextStyles.bodyRegular,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(Routes.tenantDirectory);
            },
            child: const Text('View tenants'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset form for next tenant
              _formKey.currentState?.reset();
              _nameCtrl.clear(); _mobileCtrl.clear(); _emailCtrl.clear();
              _unitCtrl.clear(); _rentCtrl.clear(); _notesCtrl.clear();
              setState(() {
                _startDate = DateTime.now();
                _startDateCtrl.text = _formatDate(_startDate);
                _tenantType = 'room';
                _elecMode = 'meter';
                _createLogin = false;
              });
            },
            child: const Text('Add another'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Add tenant', style: AppTextStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Cancel',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Tenant info section ─────────────────────────
            _SectionHeader('Tenant information'),
            const SizedBox(height: 12),

            AppTextField(
              label: 'Full name *',
              hint: 'e.g. Manoj Kumar',
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => Validators.required(v, fieldName: 'Full name'),
            ),
            const SizedBox(height: 14),

            AppTextField(
              label: 'Mobile number *',
              hint: '98765 43210',
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.phone_outlined,
              validator: Validators.mobile,
            ),
            const SizedBox(height: 14),

            // Toggle: create login account
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create login account', style: AppTextStyles.bodyMedium),
                            Text(
                              'Tenant can sign in and view their account',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _createLogin,
                        onChanged: (v) => setState(() => _createLogin = v),
                      ),
                    ],
                  ),
                  if (_createLogin) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Email address *',
                      hint: 'tenant@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_outlined,
                      validator: _createLogin ? Validators.email : null,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.actionBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.actionBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.action),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A password reset link will be emailed to the tenant.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.action),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Unit section ──────────────────────────────────
            _SectionHeader('Unit details'),
            const SizedBox(height: 12),

            AppTextField(
              label: 'Unit / Room ID *',
              hint: 'e.g. Room 03, Shop A',
              controller: _unitCtrl,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.door_front_door_outlined,
              validator: Validators.unitId,
            ),
            const SizedBox(height: 14),

            // Tenant type toggle
            Text('Tenant type *', style: AppTextStyles.inputLabel),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'room', label: Text('Room'), icon: Icon(Icons.bed_outlined)),
                ButtonSegment(value: 'shop', label: Text('Shop'), icon: Icon(Icons.store_outlined)),
              ],
              selected: {_tenantType},
              onSelectionChanged: (s) => setState(() => _tenantType = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.actionBg,
                selectedForegroundColor: AppColors.action,
              ),
            ),
            const SizedBox(height: 14),

            AppTextField(
              label: 'Start date *',
              hint: 'DD/MM/YYYY',
              controller: _startDateCtrl,
              readOnly: true,
              prefixIcon: Icons.calendar_today_outlined,
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                onPressed: _pickDate,
              ),
              validator: Validators.date,
            ),

            const SizedBox(height: 20),

            // ── Rent section ──────────────────────────────────
            _SectionHeader('Rent'),
            const SizedBox(height: 12),

            AppTextField(
              label: 'Monthly rent (₹) *',
              hint: 'e.g. 5500',
              controller: _rentCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.currency_rupee_rounded,
              validator: Validators.positiveAmount,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            ),

            const SizedBox(height: 20),

            // ── Electricity section ───────────────────────────
            _SectionHeader('Electricity'),
            const SizedBox(height: 12),

            Text('Billing mode *', style: AppTextStyles.inputLabel),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'meter', label: Text('Meter'), icon: Icon(Icons.electric_meter_outlined)),
                ButtonSegment(value: 'fixed', label: Text('Fixed'), icon: Icon(Icons.bolt_rounded)),
                ButtonSegment(value: 'none', label: Text('None'), icon: Icon(Icons.block_rounded)),
              ],
              selected: {_elecMode},
              onSelectionChanged: (s) => setState(() => _elecMode = s.first),
            ),
            const SizedBox(height: 12),

            if (_elecMode == 'meter') ...[
              AppTextField(
                label: 'Initial meter reading',
                hint: 'e.g. 1234.50',
                controller: _initialReadingCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.speed_rounded,
                helperText: 'Reading at tenancy start. Leave blank if unknown.',
              ),
            ],
            if (_elecMode == 'fixed') ...[
              AppTextField(
                label: 'Fixed electricity charge (₹) *',
                hint: 'e.g. 800',
                controller: _fixedElecCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.bolt_rounded,
                validator: _elecMode == 'fixed' ? Validators.positiveAmount : null,
              ),
            ],
            if (_elecMode == 'none') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'No electricity charge will be billed for this tenant.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Notes ─────────────────────────────────────────
            AppTextField(
              label: 'Notes (optional)',
              hint: 'Any additional information…',
              controller: _notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              prefixIcon: Icons.notes_rounded,
            ),

            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: AppTextStyles.bodyRegular.copyWith(color: AppColors.error))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit button
            AppButton(
              label: 'Add tenant',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
              icon: Icons.person_add_outlined,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.inkLight)),
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }
}
