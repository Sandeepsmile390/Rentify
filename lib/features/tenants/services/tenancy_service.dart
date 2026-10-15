import 'package:supabase_flutter/supabase_flutter.dart';

enum TenancyActionOutcome {
  deactivated,
  deleted,
}

class TenancyService {
  /// Safely manages tenancy removal.
  /// If the tenancy has financial ledger history (charges, payments, or advances),
  /// it is deactivated (archived) to preserve audit and accounting integrity.
  /// If the tenancy has no financial records, it is safely removed.
  static Future<TenancyActionOutcome> deleteOrDeactivateTenancy(String tenancyId) async {
    final client = Supabase.instance.client;

    // 1. Check for financial records
    final paymentsRes = await client
        .from('payments')
        .select('id')
        .eq('tenancy_id', tenancyId)
        .limit(1);
    final bool hasPayments = (paymentsRes as List).isNotEmpty;

    final chargesRes = await client
        .from('charges')
        .select('id')
        .eq('tenancy_id', tenancyId)
        .limit(1);
    final bool hasCharges = (chargesRes as List).isNotEmpty;

    final advancesRes = await client
        .from('tenant_advances')
        .select('id')
        .eq('tenancy_id', tenancyId)
        .limit(1);
    final bool hasAdvances = (advancesRes as List).isNotEmpty;

    if (hasPayments || hasCharges || hasAdvances) {
      // Preserve financial records: Deactivate tenancy
      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      await client.from('tenancies').update({
        'is_active': false,
        'end_date': nowStr,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', tenancyId);

      return TenancyActionOutcome.deactivated;
    }

    // 2. No financial history: safe to delete child records in FK order
    try {
      // Advance transactions (by advance_id, not non-existent tenancy_id)
      final advRows = await client
          .from('tenant_advances')
          .select('id')
          .eq('tenancy_id', tenancyId);
      for (final adv in (advRows as List)) {
        final aId = adv['id'] as String?;
        if (aId != null) {
          await client.from('advance_transactions').delete().eq('advance_id', aId);
        }
      }
      await client.from('tenant_advances').delete().eq('tenancy_id', tenancyId);

      // Meter readings
      await client.from('meter_readings').delete().eq('tenancy_id', tenancyId);
      // Documents
      await client.from('documents').delete().eq('tenancy_id', tenancyId);
      // Rent rates
      await client.from('rent_rates').delete().eq('tenancy_id', tenancyId);
      // Electricity config
      await client.from('electricity_config').delete().eq('tenancy_id', tenancyId);
      // Tenancy itself
      await client.from('tenancies').delete().eq('id', tenancyId);
      return TenancyActionOutcome.deleted;
    } catch (_) {
      // If direct delete fails due to any database restriction, safely deactivate instead
      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      await client.from('tenancies').update({
        'is_active': false,
        'end_date': nowStr,
      }).eq('id', tenancyId);
      return TenancyActionOutcome.deactivated;
    }
  }

  /// Backward compatible alias
  static Future<TenancyActionOutcome> deleteTenancy(String tenancyId) =>
      deleteOrDeactivateTenancy(tenancyId);
}
