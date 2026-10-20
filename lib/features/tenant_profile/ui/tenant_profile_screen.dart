import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../tenants/services/tenancy_service.dart';
import 'package:intl/intl.dart';

/// Figma frame 09 — Tenant profile financial overview (admin view)
class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key, required this.tenancyId});
  final String tenancyId;

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _isLoading = true;
  String? _errorMessage;
  _ProfileData? _data;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final canonicalMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

      // 1. Tenancy
      final tenancy = await client
          .from('tenancies')
          .select('id, profile_id, unit_id, tenant_type, tenant_name, mobile, start_date, is_active, notes, login_enabled')
          .eq('id', widget.tenancyId)
          .maybeSingle();

      if (tenancy == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tenancy not found in database.';
          _data = null;
        });
        return;
      }

      final name = (tenancy['tenant_name'] as String?) ?? 'Tenant';
      final mobile = (tenancy['mobile'] as String?) ?? '';
      final unitId = (tenancy['unit_id'] as String?) ?? '—';
      final type = (tenancy['tenant_type'] as String?) == 'shop' ? 'Shop' : 'Room';
      final startDate = (tenancy['start_date'] as String?) ?? '';
      final isActive = (tenancy['is_active'] as bool?) ?? true;
      final loginEnabled = (tenancy['login_enabled'] as bool?) ?? true;
      final notes = (tenancy['notes'] as String?)?.trim();

      String? email;
      final profileId = tenancy['profile_id'] as String?;
      if (profileId != null) {
        try {
          final profileRes = await client
              .from('profiles')
              .select('email')
              .eq('id', profileId)
              .maybeSingle();
          if (profileRes != null) {
            email = profileRes['email'] as String?;
          }
        } catch (_) {}
      }
      if (email == null && mobile.isNotEmpty) {
        final cleanDigits = mobile.replaceAll(RegExp(r'\D'), '');
        email = '$cleanDigits@rentify.in';
      }

      // 2. Rent rate
      int currentRentPaise = 0;
      String rentEffectiveFrom = startDate;
      final rentRes = await client
          .from('rent_rates')
          .select('amount_paise, effective_from')
          .eq('tenancy_id', widget.tenancyId)
          .order('effective_from', ascending: false)
          .limit(1)
          .maybeSingle();
      if (rentRes != null) {
        currentRentPaise = (rentRes['amount_paise'] as num?)?.toInt() ?? 0;
        rentEffectiveFrom = (rentRes['effective_from'] as String?) ?? startDate;
      }

      // 2b. Fetch system billing day
      int billingDay = 1;
      try {
        final settingRes = await client
            .from('system_settings')
            .select('value')
            .eq('key', 'billing_day')
            .maybeSingle();
        if (settingRes != null && settingRes['value'] != null) {
          billingDay = int.tryParse(settingRes['value'].toString()) ?? 1;
        }
      } catch (_) {}
      final isBillingDateCrossed = now.day >= billingDay;

      // 3. Electricity config
      String elecMode = 'meter';
      double? initialMeterReading;
      String? initialReadingDate;
      int fixedElecAmountPaise = 0;
      final elecRes = await client
          .from('electricity_config')
          .select('mode, initial_reading, fixed_amount_paise, created_at')
          .eq('tenancy_id', widget.tenancyId)
          .maybeSingle();
      if (elecRes != null) {
        elecMode = (elecRes['mode'] as String?) ?? 'meter';
        if (elecRes['initial_reading'] != null) {
          initialMeterReading = (elecRes['initial_reading'] as num?)?.toDouble();
        }
        initialReadingDate = elecRes['created_at'] as String?;
        fixedElecAmountPaise = (elecRes['fixed_amount_paise'] as num?)?.toInt() ?? 0;
      }

      // If fixed electricity mode, automatically ensure current month's fixed bill is generated on billing date
      if (elecMode == 'fixed' && fixedElecAmountPaise > 0 && isActive) {
        final canonicalMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        try {
          await client.from('charges').upsert({
            'tenancy_id': widget.tenancyId,
            'charge_type': 'electricity',
            'billing_month': canonicalMonth,
            'amount_paise': fixedElecAmountPaise,
            'status': 'pending',
          }, onConflict: 'tenancy_id,charge_type,billing_month');
        } catch (e) {
          debugPrint('Auto fixed electricity charge notice: $e');
        }
      }

      // 4. Meter readings history (sorted by billing_month & creation time)
      final List<_MeterReadingItem> meterReadingItems = [];
      double lastMeter = initialMeterReading ?? 0.0;
      try {
        final meterHistoryRes = await client
            .from('meter_readings')
            .select('id, billing_month, previous_reading, current_reading, units_consumed, rate_paise, amount_paise, is_corrected, notes, created_at')
            .eq('tenancy_id', widget.tenancyId)
            .order('billing_month', ascending: false)
            .order('created_at', ascending: false);

        for (final m in (meterHistoryRes as List<dynamic>)) {
          meterReadingItems.add(_MeterReadingItem(
            id: (m['id'] as String?) ?? '',
            billingMonth: (m['billing_month'] as String?) ?? '',
            previousReading: (m['previous_reading'] as num?)?.toDouble() ?? 0.0,
            currentReading: (m['current_reading'] as num?)?.toDouble() ?? 0.0,
            unitsConsumed: (m['units_consumed'] as num?)?.toDouble() ?? 0.0,
            ratePaise: (m['rate_paise'] as num?)?.toInt() ?? 0,
            amountPaise: (m['amount_paise'] as num?)?.toInt() ?? 0,
            isCorrected: (m['is_corrected'] as bool?) ?? false,
            notes: m['notes'] as String?,
            createdAt: (m['created_at'] as String?) ?? '',
          ));
        }

        if (meterReadingItems.isNotEmpty) {
          lastMeter = meterReadingItems.first.currentReading;
        }
      } catch (e) {
        debugPrint('Notice loading meter readings: $e');
      }

      // 5. Query charge allocation totals view
      final allocRes = await client
          .from('charge_allocation_totals')
          .select('charge_id, charge_type, billing_month, amount_paise, allocated_paise, outstanding_paise')
          .eq('tenancy_id', widget.tenancyId)
          .order('billing_month', ascending: false);

      int rentDuePaise = 0;
      int elecDuePaise = 0;
      int currentElecPaise = 0;
      Map<String, dynamic>? currentCanonicalElecCharge;

      final List<_ChargeItem> chargeItems = [];
      final currentMonthPrefix = canonicalMonth.substring(0, 7);

      for (final r in (allocRes as List<dynamic>)) {
        final cType = (r['charge_type'] as String?) ?? 'rent';
        final amt = (r['amount_paise'] as num?)?.toInt() ?? 0;
        final out = (r['outstanding_paise'] as num?)?.toInt() ?? 0;
        final alloc = (r['allocated_paise'] as num?)?.toInt() ?? 0;
        final month = (r['billing_month'] as String?) ?? '';
        final isCurrentMonth = month.startsWith(currentMonthPrefix);

        if (out > 0) {
          if (cType == 'rent') rentDuePaise += out;
          if (cType == 'electricity') elecDuePaise += out;
        }

        if (isCurrentMonth) {
          if (cType == 'rent' && amt > 0) {
            currentRentPaise = amt;
          } else if (cType == 'electricity') {
            currentCanonicalElecCharge = r as Map<String, dynamic>;
            currentElecPaise = amt;
          }
        }

        String itemStatus;
        if (out == 0) {
          itemStatus = 'paid';
        } else if (alloc > 0) {
          itemStatus = 'partial';
        } else {
          itemStatus = 'pending';
        }

        chargeItems.add(_ChargeItem(
          label: cType == 'electricity' ? 'Electricity' : 'Rent',
          month: month,
          amountPaise: amt,
          type: cType,
          status: itemStatus,
        ));
      }

      // Electricity status for canonical month
      String elecStatus;
      if (elecMode == 'meter') {
        if (currentCanonicalElecCharge != null) {
          final amt = (currentCanonicalElecCharge['amount_paise'] as num?)?.toInt() ?? 0;
          final out = (currentCanonicalElecCharge['outstanding_paise'] as num?)?.toInt() ?? 0;
          final alloc = (currentCanonicalElecCharge['allocated_paise'] as num?)?.toInt() ?? 0;

          if (out == 0 && amt > 0) {
            elecStatus = 'Paid (${CurrencyFormatter.fromPaise(amt)})';
          } else if (out == 0 && amt == 0) {
            elecStatus = '₹0 (0 units consumed)';
          } else if (alloc > 0) {
            elecStatus = '${CurrencyFormatter.fromPaise(out)} due (Partially paid)';
          } else {
            elecStatus = CurrencyFormatter.fromPaise(amt);
          }
        } else {
          // Check if meter reading exists for this month in meter readings history
          final currentMonthReading = meterReadingItems.where((m) =>
            m.billingMonth.startsWith(currentMonthPrefix)
          ).firstOrNull;

          if (currentMonthReading != null) {
            elecStatus = CurrencyFormatter.fromPaise(currentMonthReading.amountPaise);
          } else if (isBillingDateCrossed) {
            elecStatus = 'Awaiting reading';
          } else {
            final suffix = switch (billingDay) {
              1 || 21 || 31 => 'st',
              2 || 22 => 'nd',
              3 || 23 => 'rd',
              _ => 'th',
            };
            elecStatus = 'Due on $billingDay$suffix';
          }
        }
      } else if (elecMode == 'fixed') {
        final amt = currentElecPaise > 0 ? currentElecPaise : fixedElecAmountPaise;
        elecStatus = '${CurrencyFormatter.fromPaise(amt)}/month (Fixed)';
      } else {
        elecStatus = 'Not Available / No Need';
      }

      // 6. Payments
      final paymentsRes = await client
          .from('payments')
          .select('amount_paise, payment_date, method, reference')
          .eq('tenancy_id', widget.tenancyId)
          .order('payment_date', ascending: false);

      int paymentsThisMonthPaise = 0;
      final List<_PaymentItem> paymentItems = [];

      for (final p in (paymentsRes as List<dynamic>)) {
        final amt = (p['amount_paise'] as num?)?.toInt() ?? 0;
        final pDate = (p['payment_date'] as String?) ?? '';
        final method = (p['method'] as String?) ?? 'cash';
        final ref = p['reference'] as String?;

        if (pDate.startsWith(currentMonthPrefix)) {
          paymentsThisMonthPaise += amt;
        }

        paymentItems.add(_PaymentItem(
          date: pDate,
          amountPaise: amt,
          method: method == 'online' ? 'Online' : 'Cash',
          reference: ref,
        ));
      }

      // 7. Advance balance
      int advanceBalancePaise = 0;
      final advRes = await client
          .from('tenant_advances')
          .select('id')
          .eq('tenancy_id', widget.tenancyId)
          .maybeSingle();

      if (advRes != null) {
        final txnsRes = await client
            .from('advance_transactions')
            .select('amount_paise')
            .eq('advance_id', advRes['id']);
        for (final t in (txnsRes as List<dynamic>)) {
          advanceBalancePaise += ((t['amount_paise'] as num?)?.toInt() ?? 0);
        }
      }

      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final currentBillingMonth = '${monthNames[now.month - 1]} ${now.year}';

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _data = _ProfileData(
          name: name,
          mobile: mobile,
          unitId: unitId,
          type: type,
          billingMonth: currentBillingMonth,
          rentEffectiveFrom: rentEffectiveFrom,
          startDate: startDate,
          elecMode: elecMode,
          isActive: isActive,
          loginEnabled: loginEnabled,
          rentDuePaise: rentDuePaise,
          elecDuePaise: elecDuePaise,
          advanceBalancePaise: advanceBalancePaise,
          currentRentPaise: currentRentPaise,
          currentElecPaise: currentElecPaise,
          fixedElecAmountPaise: fixedElecAmountPaise,
          elecStatus: elecStatus,
          paymentsThisMonthPaise: paymentsThisMonthPaise,
          lastMeterReading: lastMeter,
          initialMeterReading: initialMeterReading,
          initialReadingDate: initialReadingDate,
          meterReadings: meterReadingItems,
          email: email,
          notes: notes,
          charges: chargeItems,
          payments: paymentItems,
        );
      });
    } catch (e) {
      debugPrint('Error loading tenant profile: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tenant profile: $e';
        _data = null;
      });
    }
  }

  Future<void> _handleToggleLogin(bool enabled) async {
    final prevEnabled = _data?.loginEnabled ?? !enabled;
    setState(() {
      if (_data != null) {
        _data = _data!.copyWith(loginEnabled: enabled);
      }
    });

    try {
      final client = Supabase.instance.client;
      try {
        await client.rpc('admin_toggle_tenant_login', params: {
          'p_tenancy_id': widget.tenancyId,
          'p_enabled': enabled,
        });
      } catch (rpcErr) {
        debugPrint('RPC admin_toggle_tenant_login fallback to table update: $rpcErr');
        await client.from('tenancies').update({
          'login_enabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.tenancyId);

        try {
          final tRow = await client
              .from('tenancies')
              .select('profile_id')
              .eq('id', widget.tenancyId)
              .maybeSingle();
          if (tRow != null && tRow['profile_id'] != null) {
            await client.from('profiles').update({
              'login_enabled': enabled,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', tRow['profile_id']);
          }
        } catch (_) {}
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'Tenant login enabled. Resident can access portal.'
              : 'Tenant login disabled. Active sessions revoked.'),
          backgroundColor: enabled ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_data != null) {
            _data = _data!.copyWith(loginEnabled: prevEnabled);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update tenant login: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showEditTenantDialog() async {
    if (!mounted || _data == null) return;

    final nameCtrl = TextEditingController(text: _data!.name);
    final mobileCtrl = TextEditingController(text: _data!.mobile);
    final emailCtrl = TextEditingController(text: _data!.email ?? '');
    final unitCtrl = TextEditingController(text: _data!.unitId);
    final rentCtrl = TextEditingController(
      text: _data!.currentRentPaise > 0
          ? (_data!.currentRentPaise / 100).toStringAsFixed(0)
          : '',
    );
    final notesCtrl = TextEditingController(text: _data!.notes ?? '');

    String selectedType = _data!.type.toLowerCase() == 'shop' ? 'shop' : 'room';
    bool isActive = _data!.isActive;
    DateTime parsedStartDate = DateTime.tryParse(_data!.startDate) ?? DateTime.now();
    DateTime? parsedEndDate = isActive ? null : DateTime.now();

    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            final isSaving = ValueNotifier<bool>(false);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.action.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: AppColors.action),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Tenant Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Update contact, tenancy status & rent', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter name' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: mobileCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Mobile Number *',
                                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter mobile';
                                  final digits = v.replaceAll(RegExp(r'\D'), '');
                                  if (digits.length < 10) return 'Min 10 digits';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: unitCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Unit / Room ID *',
                                  prefixIcon: Icon(Icons.home_outlined, size: 20),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter unit ID' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address (optional)',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'Tenant Type',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'room', child: Text('Room')),
                                  DropdownMenuItem(value: 'shop', child: Text('Shop')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<bool>(
                                value: isActive,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: true,
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                        SizedBox(width: 6),
                                        Text('Active'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                                        SizedBox(width: 6),
                                        Text('Left / Vacated'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      isActive = val;
                                      if (!isActive && parsedEndDate == null) {
                                        parsedEndDate = DateTime.now();
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: sbCtx,
                              initialDate: parsedStartDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => parsedStartDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date *',
                              prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(parsedStartDate)),
                          ),
                        ),
                        if (!isActive) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: sbCtx,
                                initialDate: parsedEndDate ?? DateTime.now(),
                                firstDate: parsedStartDate,
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => parsedEndDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date / Date Vacated *',
                                prefixIcon: Icon(Icons.event_busy_rounded, size: 18),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              child: Text(DateFormat('yyyy-MM-dd').format(parsedEndDate ?? DateTime.now())),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: rentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Monthly Rent (₹)',
                            prefixIcon: Icon(Icons.currency_rupee_rounded, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Internal Notes / Remarks',
                            prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isSaving,
                  builder: (ctx, saving, _) => FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            isSaving.value = true;
                            try {
                              final client = Supabase.instance.client;
                              final name = nameCtrl.text.trim();
                              final mobile = mobileCtrl.text.trim();
                              final email = emailCtrl.text.trim();
                              final unitId = unitCtrl.text.trim();
                              final rentVal = double.tryParse(rentCtrl.text.trim()) ?? 0;
                              final rentPaise = (rentVal * 100).round();
                              final notes = notesCtrl.text.trim();
                              final startDateStr = DateFormat('yyyy-MM-dd').format(parsedStartDate);
                              final endDateStr = (!isActive && parsedEndDate != null)
                                  ? DateFormat('yyyy-MM-dd').format(parsedEndDate!)
                                  : null;

                              try {
                                await client.rpc('admin_update_tenant_details', params: {
                                  'p_tenancy_id': widget.tenancyId,
                                  'p_tenant_name': name,
                                  'p_mobile': mobile,
                                  'p_email': email.isEmpty ? null : email,
                                  'p_unit_id': unitId,
                                  'p_tenant_type': selectedType,
                                  'p_start_date': startDateStr,
                                  'p_is_active': isActive,
                                  'p_end_date': endDateStr,
                                  'p_rent_paise': rentPaise > 0 ? rentPaise : null,
                                  'p_notes': notes.isEmpty ? null : notes,
                                });
                              } catch (rpcErr) {
                                debugPrint('RPC admin_update_tenant_details fallback: $rpcErr');
                                await client.from('tenancies').update({
                                  'tenant_name': name,
                                  'mobile': mobile.isEmpty ? null : mobile,
                                  'unit_id': unitId,
                                  'tenant_type': selectedType,
                                  'start_date': startDateStr,
                                  'is_active': isActive,
                                  'end_date': endDateStr,
                                  'notes': notes.isEmpty ? null : notes,
                                  'updated_at': DateTime.now().toIso8601String(),
                                }).eq('id', widget.tenancyId);

                                if (rentPaise > 0) {
                                  await client.from('rent_rates').insert({
                                    'tenancy_id': widget.tenancyId,
                                    'amount_paise': rentPaise,
                                    'effective_from': startDateStr,
                                  });
                                }
                              }

                              if (dCtx.mounted) Navigator.pop(dCtx, true);
                            } catch (e) {
                              isSaving.value = false;
                              if (dCtx.mounted) {
                                ScaffoldMessenger.of(dCtx).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update tenant: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenant details updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _showEditNotesDialog(
    BuildContext context,
    String tenancyId,
    String? currentNotes,
  ) async {
    final ctrl = TextEditingController(text: currentNotes ?? '');
    final res = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.action),
            SizedBox(width: 8),
            Text('Notes & Remarks'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add internal comments, payment agreements, or notes for this tenant:',
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. Deposit receipt number, special rent terms, notice dates...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (res == true) {
      try {
        final client = Supabase.instance.client;
        final updatedText = ctrl.text.trim();
        await client
            .from('tenancies')
            .update({'notes': updatedText.isEmpty ? null : updatedText})
            .eq('id', tenancyId);

        await _load();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tenancy notes saved successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save notes: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Tenant record not found', style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage ?? 'This tenancy does not exist or was deleted.',
                          style: AppTextStyles.bodyRegular,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : NestedScrollView(
                  headerSliverBuilder: (ctx, _) => [
                    _ProfileAppBar(
                      data: _data!,
                      tenancyId: widget.tenancyId,
                      onRefresh: _load,
                      onEdit: _showEditTenantDialog,
                    ),
                _FinancialSummaryBar(
                  data: _data!,
                  isWide: isWide,
                  tenancyId: widget.tenancyId,
                ),
                _TabBar(controller: _tabCtrl, elecMode: _data!.elecMode),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _OverviewTab(
                      data: _data!,
                      tenancyId: widget.tenancyId,
                      onRefresh: _load,
                      onEditNotes: (notes) => _showEditNotesDialog(context, widget.tenancyId, notes),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _ChargesTab(data: _data!),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _PaymentsTab(data: _data!),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _MeterTab(
                      data: _data!,
                      tenancyId: widget.tenancyId,
                      onRefresh: _load,
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _DetailsTab(
                      data: _data!,
                      tenancyId: widget.tenancyId,
                      onToggleLogin: _handleToggleLogin,
                      onEditNotes: (notes) => _showEditNotesDialog(context, widget.tenancyId, notes),
                      onEditTenant: _showEditTenantDialog,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.pushNamed(
                  'record-payment',
                  pathParameters: {'tenancyId': widget.tenancyId},
                );
                await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record payment'),
              tooltip: 'Record a payment for this tenant',
            ),
    );
  }
}

// ── Profile app bar ───────────────────────────────────────────────

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({
    required this.data,
    required this.tenancyId,
    required this.onRefresh,
    required this.onEdit,
  });
  final _ProfileData data;
  final String tenancyId;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.navy,
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Text(
                  data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.name,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${data.unitId} · ${data.type}',
                            style: AppTextStyles.captionBold.copyWith(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          label: data.isActive ? 'Active' : 'Inactive',
                          type: data.isActive ? StatusChipType.success : StatusChipType.neutral,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: 'Edit tenant details',
          onPressed: onEdit,
        ),
        if (data.elecMode == 'meter')
          IconButton(
            icon: const Icon(Icons.electric_meter_outlined, color: Colors.white),
            tooltip: 'Enter meter reading',
            onPressed: () async {
              final updated = await context.pushNamed(
                'meter-reading',
                pathParameters: {'tenancyId': tenancyId},
              );
              if (updated == true) {
                await onRefresh();
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          tooltip: 'Delete tenant',
          onPressed: () => _confirmDeleteTenant(context, tenancyId, data.name),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          tooltip: 'More actions',
          onPressed: () => _showActionsSheet(context),
        ),
      ],
    );
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: AppColors.action),
              title: const Text('Edit tenant details'),
              subtitle: const Text('Update name, phone, status, start date, rent'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt_rounded, color: AppColors.action),
              title: const Text('Electricity Setup'),
              subtitle: Text(data.elecMode == 'meter'
                  ? 'Meter-based (Unit readings)'
                  : (data.elecMode == 'fixed'
                      ? 'Fixed (₹${(data.fixedElecAmountPaise / 100).toStringAsFixed(0)}/mo auto-billed)'
                      : 'No meter (Not available / No need)')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showElectricityModeDialog(context, tenancyId, data, onRefresh);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: const Text('Advance / Deposit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.pushNamed('advances', pathParameters: {'tenancyId': tenancyId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Audit trail'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.pushNamed('audit-trail', pathParameters: {'tenancyId': tenancyId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
              title: const Text('Send WhatsApp dues summary'),
              subtitle: const Text('Exact breakdown or fully-cleared notice'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _sendWhatsAppDuesSummary(context, data, tenancyId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.password_rounded, color: AppColors.action),
              title: const Text('Set / Reset tenant password'),
              subtitle: const Text('Configure portal password for this resident'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showSetPasswordDialog(context, tenancyId, data.name, data.mobile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Documents'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.pushNamed('documents', pathParameters: {'tenancyId': tenancyId});
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              title: const Text('Delete tenant', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDeleteTenant(context, tenancyId, data.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Financial summary bar ─────────────────────────────────────────

class _FinancialSummaryBar extends StatelessWidget {
  const _FinancialSummaryBar({
    required this.data,
    required this.isWide,
    required this.tenancyId,
  });
  final _ProfileData data;
  final bool isWide;
  final String tenancyId;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: isWide
            ? Row(
                children: [
                  _FinStat(label: 'Rent due', value: CurrencyFormatter.fromPaise(data.rentDuePaise), color: data.rentDuePaise > 0 ? AppColors.amountDue : AppColors.success),
                  _Divider(),
                  _FinStat(label: 'Electricity due', value: CurrencyFormatter.fromPaise(data.elecDuePaise), color: data.elecDuePaise > 0 ? AppColors.warning : AppColors.success),
                  _Divider(),
                  _FinStat(label: 'Current advance', value: CurrencyFormatter.fromPaise(data.advanceBalancePaise), color: AppColors.action),
                  _Divider(),
                  _FinStat(label: 'Total outstanding', value: CurrencyFormatter.fromPaise(data.totalDuePaise), color: data.totalDuePaise > 0 ? AppColors.amountDue : AppColors.success, isLarge: true),
                ],
              )
            : Column(
                children: [
                  // 3-Stat Top Row: Rent Due | Electricity Due | Current Advance
                  Row(
                    children: [
                      Expanded(
                        child: _FinStat(
                          label: 'Rent due',
                          value: CurrencyFormatter.fromPaise(data.rentDuePaise),
                          color: data.rentDuePaise > 0 ? AppColors.amountDue : AppColors.success,
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppColors.border),
                      Expanded(
                        child: _FinStat(
                          label: 'Electricity due',
                          value: CurrencyFormatter.fromPaise(data.elecDuePaise),
                          color: data.elecDuePaise > 0 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppColors.border),
                      Expanded(
                        child: _FinStat(
                          label: 'Current advance',
                          value: CurrencyFormatter.fromPaise(data.advanceBalancePaise),
                          color: AppColors.action,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tap-able Split Banner: Total Outstanding & Security Advance
                  InkWell(
                    onTap: () {
                      context.pushNamed('advances', pathParameters: {'tenancyId': tenancyId});
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: data.totalDuePaise > 0 ? AppColors.errorBg : AppColors.successBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: data.totalDuePaise > 0 ? AppColors.errorBorder : AppColors.successBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total outstanding', style: AppTextStyles.captionBold),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.fromPaise(data.totalDuePaise),
                                style: AppTextStyles.currencyMedium.copyWith(
                                  color: data.totalDuePaise > 0 ? AppColors.amountDue : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.action),
                                      const SizedBox(width: 4),
                                      Text('Advance held', style: AppTextStyles.captionBold.copyWith(color: AppColors.action)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.fromPaise(data.advanceBalancePaise),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.action,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.action),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FinStat extends StatelessWidget {
  const _FinStat({required this.label, required this.value, required this.color, this.isLarge = false});
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: (isLarge ? AppTextStyles.currencyMedium : AppTextStyles.currencySmall)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

// ── Tab bar ───────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller, this.elecMode = 'meter'});
  final TabController controller;
  final String elecMode;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.surface,
        child: TabBar(
          controller: controller,
          labelStyle: AppTextStyles.captionBold,
          unselectedLabelStyle: AppTextStyles.caption,
          labelColor: AppColors.action,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.action,
          indicatorWeight: 2,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Charges'),
            const Tab(text: 'Payments'),
            Tab(text: elecMode == 'meter' ? 'Meter' : 'Electricity'),
            const Tab(text: 'Details'),
          ],
        ),
      ),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.data,
    required this.tenancyId,
    required this.onRefresh,
    required this.onEditNotes,
  });
  final _ProfileData data;
  final String tenancyId;
  final Future<void> Function() onRefresh;
  final void Function(String?) onEditNotes;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick actions
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Record payment',
                type: AppButtonType.primary,
                icon: Icons.payments_outlined,
                onPressed: () async {
                  await context.pushNamed(
                    'record-payment',
                    pathParameters: {'tenancyId': tenancyId},
                  );
                  await onRefresh();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: data.elecMode == 'meter'
                  ? AppButton(
                      label: 'Meter reading',
                      type: AppButtonType.outlined,
                      icon: Icons.electric_meter_outlined,
                      onPressed: () async {
                        final updated = await context.pushNamed(
                          'meter-reading',
                          pathParameters: {'tenancyId': tenancyId},
                        );
                        if (updated == true) {
                          await onRefresh();
                        }
                      },
                    )
                  : (data.elecMode == 'fixed'
                      ? AppButton(
                          label: 'Fixed: ₹${(data.fixedElecAmountPaise / 100).toStringAsFixed(0)}',
                          type: AppButtonType.outlined,
                          icon: Icons.bolt_rounded,
                          onPressed: () => _showElectricityModeDialog(
                            context,
                            tenancyId,
                            data,
                            onRefresh,
                          ),
                        )
                      : AppButton(
                          label: 'No meter',
                          type: AppButtonType.outlined,
                          icon: Icons.tune_rounded,
                          onPressed: () => _showElectricityModeDialog(
                            context,
                            tenancyId,
                            data,
                            onRefresh,
                          ),
                        )),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // WhatsApp dues summary button
        AppButton(
          label: 'Send WhatsApp dues summary',
          type: AppButtonType.outlined,
          icon: Icons.chat_rounded,
          onPressed: () async {
            final rentOutstanding = data.charges
                .where((c) => c.type == 'rent' && c.status != 'paid')
                .map((c) => OutstandingRentMonth(
                      billingMonth: c.month,
                      duePaise: c.amountPaise,
                    ))
                .toList();

            final payload = WhatsAppDuesSummaryPayload(
              tenantName: data.name,
              mobile: data.mobile,
              outstandingRentMonths: rentOutstanding,
              totalRentDuePaise: data.rentDuePaise,
              totalElecDuePaise: data.elecDuePaise,
            );

            await WhatsAppService.shareDuesSummary(
              context: context,
              payload: payload,
            );
          },
        ),
        const SizedBox(height: 16),

        // Current month summary
        _SectionCard(
          title: 'This month',
          child: Column(
            children: [
              _InfoRow('Billing month', data.billingMonth),
              _InfoRow('Rent charge', CurrencyFormatter.fromPaise(data.currentRentPaise)),
              _InfoRow('Electricity charge', data.elecStatus),
              _InfoRow('Payments received', CurrencyFormatter.fromPaise(data.paymentsThisMonthPaise)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rent info
        _SectionCard(
          title: 'Rent',
          action: TextButton.icon(
            icon: const Icon(Icons.trending_up, size: 16),
            label: const Text('Revise / Increase'),
            onPressed: () => _showReviseRentDialog(context, tenancyId, data, onRefresh),
          ),
          child: Column(
            children: [
              _InfoRow('Current rate', '${CurrencyFormatter.fromPaise(data.currentRentPaise)}/month'),
              _InfoRow('Effective from', data.rentEffectiveFrom),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Electricity
        _SectionCard(
          title: 'Electricity',
          child: Column(
            children: [
              _InfoRow('Mode', data.elecMode == 'meter' ? 'Meter-based' : data.elecMode == 'fixed' ? 'Fixed amount' : 'Not billed'),
              if (data.elecMode == 'meter') ...[
                if (data.initialMeterReading != null)
                  _InfoRow('Initial reading', '${data.initialMeterReading!.toStringAsFixed(1)} units'),
                _InfoRow('Last reading', '${data.lastMeterReading.toStringAsFixed(1)} units'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notes & Remarks
        _NotesSectionCard(
          notes: data.notes,
          onEdit: () => onEditNotes(data.notes),
        ),
        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTextStyles.h3),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyRegular),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ── Charges tab ───────────────────────────────────────────────────

class _ChargesTab extends StatelessWidget {
  const _ChargesTab({required this.data});
  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.charges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = data.charges[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.type == 'rent' ? AppColors.actionBg : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  c.type == 'rent' ? Icons.home_outlined : Icons.bolt_rounded,
                  size: 18,
                  color: c.type == 'rent' ? AppColors.action : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.label, style: AppTextStyles.bodyMedium),
                  Text(c.month, style: AppTextStyles.caption),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(CurrencyFormatter.fromPaise(c.amountPaise), style: AppTextStyles.currencySmall),
                const SizedBox(height: 4),
                StatusChip(
                  label: _statusLabel(c.status),
                  type: _statusType(c.status),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String s) => switch (s) {
    'paid' => 'Paid',
    'partial' => 'Partial',
    'pending' => 'Pending',
    'waived' => 'Waived',
    _ => s,
  };

  StatusChipType _statusType(String s) => switch (s) {
    'paid' => StatusChipType.success,
    'partial' => StatusChipType.warning,
    'pending' => StatusChipType.error,
    'waived' => StatusChipType.neutral,
    _ => StatusChipType.neutral,
  };
}

// ── Payments tab ──────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.data});
  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = data.payments[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payments_outlined, size: 18, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.date, style: AppTextStyles.bodyMedium),
                  Text('${p.method} ${p.reference != null ? "· ${p.reference}" : ""}', style: AppTextStyles.caption),
                ]),
              ),
              Text(
                CurrencyFormatter.fromPaise(p.amountPaise),
                style: AppTextStyles.currencySmall.copyWith(color: AppColors.success),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Meter readings tab ─────────────────────────────────────────────

class _MeterTab extends StatelessWidget {
  const _MeterTab({
    required this.data,
    required this.tenancyId,
    required this.onRefresh,
  });

  final _ProfileData data;
  final String tenancyId;
  final Future<void> Function() onRefresh;

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  String _formatMonth(String canonicalMonth) {
    try {
      final parts = canonicalMonth.split('-');
      if (parts.length >= 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return DateFormat('MMMM yyyy').format(dt);
      }
    } catch (_) {}
    return canonicalMonth;
  }

  Widget _buildFixedCard(BuildContext context) {
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
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fixed Electricity Mode', style: AppTextStyles.h3),
                    Text(
                      '₹${(data.fixedElecAmountPaise / 100).toStringAsFixed(0)} / month',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.action, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const StatusChip(
                label: 'Fixed Mode',
                type: StatusChipType.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-Billed on Billing Date', style: AppTextStyles.captionBold),
                      const SizedBox(height: 2),
                      Text(
                        'No meter reading is required or asked. A recurring charge of ₹${(data.fixedElecAmountPaise / 100).toStringAsFixed(0)} is automatically generated every month on the tenancy billing date.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showElectricityModeDialog(context, tenancyId, data, onRefresh),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Change Mode or Fixed Amount'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoneCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.power_off_rounded, color: AppColors.inkMuted, size: 28),
          ),
          const SizedBox(height: 12),
          Text('No Meter / Not Available', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            'Electricity is either included in rent or not separately metered for this tenant.\nNo meter readings are required or asked.',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showElectricityModeDialog(context, tenancyId, data, onRefresh),
                  icon: const Icon(Icons.electric_meter_outlined, size: 18),
                  label: const Text('Switch to Reading'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showElectricityModeDialog(context, tenancyId, data, onRefresh),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Switch to Fixed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeteredCard(BuildContext context, double totalUnitsConsumed) {
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.electric_meter_rounded, color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Electricity Meter Setup', style: AppTextStyles.h3),
                    Text(
                      'Metered Billing (per-unit)',
                      style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const StatusChip(
                label: 'Meter-based',
                type: StatusChipType.neutral,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Baseline / Initial reading details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Initial Reading (Baseline)', style: AppTextStyles.captionBold.copyWith(color: AppColors.inkMuted)),
                    const SizedBox(height: 4),
                    Text(
                      data.initialMeterReading != null
                          ? '${data.initialMeterReading!.toStringAsFixed(1)} units'
                          : '0.0 units',
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (data.initialReadingDate != null && data.initialReadingDate!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Initialized: ${_formatDate(data.initialReadingDate!)}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Latest Reading', style: AppTextStyles.captionBold.copyWith(color: AppColors.inkMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '${data.lastMeterReading.toStringAsFixed(1)} units',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total consumed: ${totalUnitsConsumed.toStringAsFixed(1)} units',
                      style: AppTextStyles.caption.copyWith(color: AppColors.action, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons: record new reading + switch mode
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.pushNamed(
                      'meter-reading',
                      pathParameters: {'tenancyId': tenancyId},
                    );
                    await onRefresh();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Record Reading'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showElectricityModeDialog(context, tenancyId, data, onRefresh),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Switch Mode'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReadings = data.meterReadings.isNotEmpty;
    final totalUnitsConsumed = data.meterReadings.fold<double>(
      0.0,
      (sum, item) => sum + item.unitsConsumed,
    );
    final elecCharges = data.charges.where((c) => c.type == 'electricity').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.elecMode == 'fixed') ...[
          _buildFixedCard(context),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Electricity Charges History', style: AppTextStyles.h3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${elecCharges.length} bills',
                  style: AppTextStyles.captionBold.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (elecCharges.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bolt_rounded, size: 40, color: AppColors.inkMuted),
                  const SizedBox(height: 12),
                  Text('No electricity charges generated yet', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Fixed electricity bills are auto-generated on the billing date every month.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: elecCharges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final c = elecCharges[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.warning),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.label, style: AppTextStyles.bodyMedium),
                              Text(_formatMonth(c.month), style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.fromPaise(c.amountPaise),
                            style: AppTextStyles.currencySmall.copyWith(color: AppColors.action),
                          ),
                          StatusChip(
                            label: c.status.toUpperCase(),
                            type: c.status == 'paid' ? StatusChipType.success : StatusChipType.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ] else if (data.elecMode == 'none') ...[
          _buildNoneCard(context),
        ] else ...[
          _buildMeteredCard(context, totalUnitsConsumed),
          const SizedBox(height: 20),

          // Meter Readings History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Meter Readings History', style: AppTextStyles.h3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${data.meterReadings.length} records',
                  style: AppTextStyles.captionBold.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!hasReadings)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.speed_rounded, size: 40, color: AppColors.inkMuted),
                  const SizedBox(height: 12),
                  Text('No meter readings recorded yet', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Record monthly electricity readings to calculate consumption and dues automatically.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.meterReadings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = data.meterReadings[i];
                return Container(
                  padding: const EdgeInsets.all(14),
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
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.action),
                              const SizedBox(width: 6),
                              Text(
                                _formatMonth(item.billingMonth),
                                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${item.unitsConsumed.toStringAsFixed(1)} units',
                              style: AppTextStyles.captionBold.copyWith(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Added: ${_formatDate(item.createdAt)}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Previous → Current', style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                              const SizedBox(height: 2),
                              Text(
                                '${item.previousReading.toStringAsFixed(1)} → ${item.currentReading.toStringAsFixed(1)}',
                                style: AppTextStyles.bodyRegular,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.fromPaise(item.amountPaise),
                                style: AppTextStyles.currencySmall.copyWith(color: AppColors.action),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@ ₹${(item.ratePaise / 100.0).toStringAsFixed(2)} / unit',
                                style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.notes!,
                            style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Details tab ───────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.data,
    required this.tenancyId,
    required this.onToggleLogin,
    required this.onEditNotes,
    required this.onEditTenant,
  });
  final _ProfileData data;
  final String tenancyId;
  final void Function(bool) onToggleLogin;
  final void Function(String?) onEditNotes;
  final VoidCallback onEditTenant;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.action.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: AppColors.action, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tenant Information', style: AppTextStyles.h3.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        'Update status, name, mobile, email, rent, or tenancy dates.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onEditTenant,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Details'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Tenancy details',
          action: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.action),
            tooltip: 'Edit details',
            onPressed: onEditTenant,
          ),
          child: Column(
            children: [
              _InfoRow('Unit ID', data.unitId),
              _InfoRow('Tenant type', data.type),
              _InfoRow('Start date', data.startDate),
              _InfoRow('Status', data.isActive ? 'Active' : 'Inactive / Left'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Contact',
          child: Column(
            children: [
              _InfoRow('Name', data.name),
              _InfoRow('Mobile', data.mobile),
              if (data.email != null) _InfoRow('Email', data.email!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _NotesSectionCard(
          notes: data.notes,
          onEdit: () => onEditNotes(data.notes),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Portal access',
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text('Tenant login enabled', style: AppTextStyles.bodyMedium),
                subtitle: Text(
                  data.loginEnabled
                      ? 'Active — resident can log into tenant portal using mobile number'
                      : 'Disabled — portal login is blocked and active sessions are revoked',
                  style: AppTextStyles.caption.copyWith(
                    color: data.loginEnabled ? AppColors.success : AppColors.error,
                  ),
                ),
                value: data.loginEnabled,
                activeColor: AppColors.action,
                onChanged: onToggleLogin,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Danger zone',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Permanently remove this tenant and delete all their associated charges, payments, and meter readings.',
                style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text('Delete this tenant', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () => _confirmDeleteTenant(context, tenancyId, data.name),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Notes card ────────────────────────────────────────────────────

class _NotesSectionCard extends StatelessWidget {
  const _NotesSectionCard({
    required this.notes,
    required this.onEdit,
  });
  final String? notes;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes != null && notes!.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_alt_outlined, size: 18, color: AppColors.action),
                    const SizedBox(width: 8),
                    Text('Notes & Remarks', style: AppTextStyles.h3),
                  ],
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(hasNotes ? Icons.edit_outlined : Icons.add_rounded, size: 16),
                  label: Text(hasNotes ? 'Edit' : 'Add Note', style: const TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: hasNotes
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      notes!,
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  )
                : Text(
                    'No remarks or notes recorded for this tenancy yet. Tap "Add Note" to write one.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Profile data models ──────────────────────────────────────────

class _MeterReadingItem {
  final String id;
  final String billingMonth;
  final double previousReading;
  final double currentReading;
  final double unitsConsumed;
  final int ratePaise;
  final int amountPaise;
  final bool isCorrected;
  final String? notes;
  final String createdAt;

  const _MeterReadingItem({
    required this.id,
    required this.billingMonth,
    required this.previousReading,
    required this.currentReading,
    required this.unitsConsumed,
    required this.ratePaise,
    required this.amountPaise,
    this.isCorrected = false,
    this.notes,
    required this.createdAt,
  });
}

class _ProfileData {
  final String name, mobile, unitId, type, billingMonth, rentEffectiveFrom, startDate, elecMode, elecStatus;
  final String? email, notes;
  final bool isActive, loginEnabled;
  final int rentDuePaise, elecDuePaise, advanceBalancePaise, currentRentPaise, currentElecPaise, paymentsThisMonthPaise;
  final int fixedElecAmountPaise;
  final double lastMeterReading;
  final double? initialMeterReading;
  final String? initialReadingDate;
  final List<_MeterReadingItem> meterReadings;
  final List<_ChargeItem> charges;
  final List<_PaymentItem> payments;

  const _ProfileData({
    required this.name, required this.mobile, required this.unitId,
    required this.type, required this.billingMonth, required this.rentEffectiveFrom,
    required this.startDate, required this.elecMode, required this.elecStatus,
    this.email, this.notes, required this.isActive, required this.loginEnabled,
    required this.rentDuePaise, required this.elecDuePaise, required this.advanceBalancePaise,
    required this.currentRentPaise, required this.currentElecPaise, required this.paymentsThisMonthPaise,
    this.fixedElecAmountPaise = 0,
    required this.lastMeterReading,
    this.initialMeterReading,
    this.initialReadingDate,
    this.meterReadings = const [],
    required this.charges, required this.payments,
  });

  _ProfileData copyWith({
    String? name,
    String? mobile,
    String? unitId,
    String? type,
    String? billingMonth,
    String? rentEffectiveFrom,
    String? startDate,
    String? elecMode,
    String? elecStatus,
    String? email,
    String? notes,
    bool? isActive,
    bool? loginEnabled,
    int? rentDuePaise,
    int? elecDuePaise,
    int? advanceBalancePaise,
    int? currentRentPaise,
    int? currentElecPaise,
    int? paymentsThisMonthPaise,
    int? fixedElecAmountPaise,
    double? lastMeterReading,
    double? initialMeterReading,
    String? initialReadingDate,
    List<_MeterReadingItem>? meterReadings,
    List<_ChargeItem>? charges,
    List<_PaymentItem>? payments,
  }) {
    return _ProfileData(
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      unitId: unitId ?? this.unitId,
      type: type ?? this.type,
      billingMonth: billingMonth ?? this.billingMonth,
      rentEffectiveFrom: rentEffectiveFrom ?? this.rentEffectiveFrom,
      startDate: startDate ?? this.startDate,
      elecMode: elecMode ?? this.elecMode,
      elecStatus: elecStatus ?? this.elecStatus,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      loginEnabled: loginEnabled ?? this.loginEnabled,
      rentDuePaise: rentDuePaise ?? this.rentDuePaise,
      elecDuePaise: elecDuePaise ?? this.elecDuePaise,
      advanceBalancePaise: advanceBalancePaise ?? this.advanceBalancePaise,
      currentRentPaise: currentRentPaise ?? this.currentRentPaise,
      currentElecPaise: currentElecPaise ?? this.currentElecPaise,
      paymentsThisMonthPaise: paymentsThisMonthPaise ?? this.paymentsThisMonthPaise,
      fixedElecAmountPaise: fixedElecAmountPaise ?? this.fixedElecAmountPaise,
      lastMeterReading: lastMeterReading ?? this.lastMeterReading,
      initialMeterReading: initialMeterReading ?? this.initialMeterReading,
      initialReadingDate: initialReadingDate ?? this.initialReadingDate,
      meterReadings: meterReadings ?? this.meterReadings,
      charges: charges ?? this.charges,
      payments: payments ?? this.payments,
    );
  }

  int get totalDuePaise => rentDuePaise + elecDuePaise;
}

class _ChargeItem {
  final String label, month, type, status;
  final int amountPaise;
  const _ChargeItem({required this.label, required this.month, required this.amountPaise, required this.type, required this.status});
}

class _PaymentItem {
  final String date, method;
  final String? reference;
  final int amountPaise;
  const _PaymentItem({required this.date, required this.amountPaise, required this.method, required this.reference});
}

Future<void> _confirmDeleteTenant(BuildContext context, String tenancyId, String tenantName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Delete from Database?'),
        ],
      ),
      content: Text(
        'Are you sure you want to permanently delete $tenantName from the database?\n\n'
        'This will permanently delete the tenancy and all related records (charges, payments, meter readings, and advance ledgers) from the database.\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete Permanently'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text('Deleting $tenantName from database…'),
        ],
      ),
      duration: const Duration(seconds: 15),
    ),
  );

  try {
    await TenancyService.deleteTenancyPermanently(tenancyId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tenant $tenantName deleted from database successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
    context.go(Routes.tenantDirectory);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to delete tenant: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

Future<void> _showSetPasswordDialog(
  BuildContext context,
  String tenancyId,
  String tenantName,
  String mobile,
) async {
  final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
  final defaultPass = cleanMobile.length >= 6 ? cleanMobile : 'RentifyTenant@2026';
  final passController = TextEditingController(text: defaultPass);
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text('Set Password for $tenantName'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set login password for $tenantName. By default, tenant User ID = mobile number ($mobile) and password = mobile number ($mobile).',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                helperText: 'Default: tenant mobile number ($cleanMobile)',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(dCtx);

            try {
              final client = Supabase.instance.client;
              await client.rpc('admin_set_tenant_password', params: {
                'p_tenancy_id': tenancyId,
                'p_new_password': passController.text.trim(),
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password set for $tenantName! They can now log in.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to set password: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          child: const Text('Save Password'),
        ),
      ],
    ),
  );
}

Future<void> _sendWhatsAppDuesSummary(
  BuildContext context,
  _ProfileData data,
  String tenancyId,
) async {
  try {
    final client = Supabase.instance.client;
    final allocRes = await client
        .from('charge_allocation_totals')
        .select('charge_type, billing_month, amount_paise, allocated_paise, outstanding_paise')
        .eq('tenancy_id', tenancyId)
        .order('billing_month', ascending: true);

    final List<OutstandingRentMonth> rentMonths = [];
    int totalRentDuePaise = 0;
    int totalElecDuePaise = 0;

    for (final r in (allocRes as List<dynamic>)) {
      final cType = (r['charge_type'] as String?) ?? 'rent';
      final out = (r['outstanding_paise'] as num?)?.toInt() ?? 0;
      final bMonth = (r['billing_month'] as String?) ?? '';

      if (out > 0) {
        if (cType == 'rent') {
          totalRentDuePaise += out;
          rentMonths.add(OutstandingRentMonth(
            billingMonth: bMonth,
            duePaise: out,
          ));
        } else if (cType == 'electricity') {
          totalElecDuePaise += out;
        }
      }
    }

    final payload = WhatsAppDuesSummaryPayload(
      tenantName: data.name,
      mobile: data.mobile,
      outstandingRentMonths: rentMonths,
      totalRentDuePaise: totalRentDuePaise,
      totalElecDuePaise: totalElecDuePaise,
    );

    if (!context.mounted) return;
    await WhatsAppService.shareDuesSummary(context: context, payload: payload);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare WhatsApp dues notice: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

Future<void> _showElectricityModeDialog(
  BuildContext context,
  String tenancyId,
  _ProfileData data,
  Future<void> Function() onRefresh,
) async {
  String selectedMode = data.elecMode;
  final fixedCtrl = TextEditingController(
    text: data.fixedElecAmountPaise > 0
        ? (data.fixedElecAmountPaise / 100).toStringAsFixed(0)
        : '',
  );
  final readingCtrl = TextEditingController(
    text: (data.initialMeterReading != null && data.initialMeterReading! > 0)
        ? data.initialMeterReading!.toStringAsFixed(1)
        : '',
  );

  final updated = await showDialog<bool>(
    context: context,
    builder: (dCtx) {
      return StatefulBuilder(
        builder: (sbCtx, setSbState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.action.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.action),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Electricity Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Configure meter or fixed monthly billing', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Electricity Mode:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 10),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Meter-based (Unit readings)'),
                    subtitle: const Text('Record meter readings periodically to calculate bill.'),
                    value: 'meter',
                    groupValue: selectedMode,
                    onChanged: (val) {
                      if (val != null) setSbState(() => selectedMode = val);
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Fixed Monthly Charge'),
                    subtitle: const Text('Auto-generates fixed electricity bill on billing date without asking meter readings.'),
                    value: 'fixed',
                    groupValue: selectedMode,
                    onChanged: (val) {
                      if (val != null) setSbState(() => selectedMode = val);
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Not Available / No Need'),
                    subtitle: const Text('Included in rent or no meter needed. No readings asked.'),
                    value: 'none',
                    groupValue: selectedMode,
                    onChanged: (val) {
                      if (val != null) setSbState(() => selectedMode = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedMode == 'fixed') ...[
                    TextFormField(
                      controller: fixedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fixed Monthly Electricity Charge (₹)',
                        prefixText: '₹ ',
                        hintText: 'e.g. 500',
                        border: OutlineInputBorder(),
                        helperText: 'Will automatically bill this amount every month.',
                      ),
                    ),
                  ] else if (selectedMode == 'meter') ...[
                    TextFormField(
                      controller: readingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Initial Meter Reading (Baseline)',
                        suffixText: 'units',
                        hintText: 'e.g. 100.0',
                        border: OutlineInputBorder(),
                        helperText: 'Starting baseline reading for new meter.',
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: AppColors.inkMuted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No electricity readings will be asked or required for this tenant.',
                              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final client = Supabase.instance.client;
                  final fixedVal = double.tryParse(fixedCtrl.text.trim()) ?? 0;
                  final fixedPaise = (selectedMode == 'fixed' && fixedVal > 0)
                      ? (fixedVal * 100).round()
                      : 0;
                  final readingVal = double.tryParse(readingCtrl.text.trim());

                  try {
                    await client.from('electricity_config').upsert({
                      'tenancy_id': tenancyId,
                      'mode': selectedMode,
                      'fixed_amount_paise': fixedPaise,
                      if (selectedMode == 'meter' && readingVal != null)
                        'initial_reading': readingVal,
                      'updated_at': DateTime.now().toIso8601String(),
                    }, onConflict: 'tenancy_id');

                    // If switched to fixed, and billing date is met, generate fixed charge
                    if (selectedMode == 'fixed' && fixedPaise > 0) {
                      final now = DateTime.now();
                      final canonicalMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
                      try {
                        await client.from('charges').upsert({
                          'tenancy_id': tenancyId,
                          'charge_type': 'electricity',
                          'billing_month': canonicalMonth,
                          'amount_paise': fixedPaise,
                          'status': 'pending',
                        }, onConflict: 'tenancy_id,charge_type,billing_month');
                      } catch (_) {}
                    }

                    if (context.mounted) {
                      Navigator.pop(dCtx, true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update electricity mode: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  if (updated == true) {
    await onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Electricity configuration updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

Future<void> _showReviseRentDialog(
  BuildContext context,
  String tenancyId,
  _ProfileData data,
  Future<void> Function() onRefresh,
) async {
  final client = Supabase.instance.client;
  final newRentCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  DateTime effectiveDate = DateTime.now();
  effectiveDate = DateTime(effectiveDate.year, effectiveDate.month, 1);
  final formKey = GlobalKey<FormState>();
  final isSaving = ValueNotifier<bool>(false);

  List<Map<String, dynamic>> rentHistory = [];
  try {
    final res = await client
        .from('rent_rates')
        .select('amount_paise, effective_from, effective_to, reason, created_at')
        .eq('tenancy_id', tenancyId)
        .order('effective_from', ascending: false);
    rentHistory = List<Map<String, dynamic>>.from(res as List);
  } catch (e) {
    debugPrint('Error loading rent history: $e');
  }
  if (!context.mounted) return;

  final updated = await showDialog<bool>(
    context: context,
    builder: (dCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.trending_up_rounded, color: AppColors.action),
                SizedBox(width: 8),
                Text('Revise / Increase Rent'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Rent Rate:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${CurrencyFormatter.fromPaise(data.currentRentPaise)} / mo',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.action, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newRentCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'New Monthly Rent (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                          hintText: 'e.g. 6700',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter new rent amount';
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Effective Month / Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(effectiveDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        trailing: const Icon(Icons.calendar_month, color: AppColors.action),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: effectiveDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              effectiveDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reason / Remarks (Optional)',
                          prefixIcon: Icon(Icons.notes, size: 20),
                          hintText: 'e.g. Annual revision, upgraded room...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (rentHistory.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Rent Rate History',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 6),
                        ...rentHistory.map((rh) {
                          final amt = (rh['amount_paise'] as num?)?.toInt() ?? 0;
                          final from = (rh['effective_from'] as String?) ?? '';
                          final reason = rh['reason'] as String?;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${CurrencyFormatter.fromPaise(amt)}/mo',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (reason != null && reason.isNotEmpty)
                                      Text(reason, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                                  ],
                                ),
                                Text(
                                  'From $from',
                                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel'),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isSaving,
                builder: (context, saving, _) => FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          isSaving.value = true;
                          try {
                            final newRentVal = double.tryParse(newRentCtrl.text.trim()) ?? 0;
                            final newRentPaise = (newRentVal * 100).round();
                            final effDateStr = DateFormat('yyyy-MM-dd').format(effectiveDate);
                            final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
                            final userId = client.auth.currentUser?.id;

                            await client.from('rent_rates').insert({
                              'tenancy_id': tenancyId,
                              'amount_paise': newRentPaise,
                              'effective_from': effDateStr,
                              'reason': reason,
                              if (userId != null) 'created_by': userId,
                            });

                            if (dCtx.mounted) Navigator.pop(dCtx, true);
                          } catch (e) {
                            isSaving.value = false;
                            if (dCtx.mounted) {
                              ScaffoldMessenger.of(dCtx).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to revise rent: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Apply Rent Revision'),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (updated == true) {
    await onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rent revised successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

