import 'package:supabase_flutter/supabase_flutter.dart';

enum TenancyActionOutcome {
  deactivated,
  deleted,
}

class TenancyService {
  /// Permanently deletes a tenancy and all its dependent records from the database.
  /// Follows strict foreign-key order:
  /// 1. advance_transactions (via advance_id & charge_id)
  /// 2. payment_allocations (via payment_id & charge_id)
  /// 3. charges (clearing reversed_by & meter_reading_id first)
  /// 4. payments
  /// 5. tenant_advances
  /// 6. meter_readings (clearing corrects_id first)
  /// 7. documents
  /// 8. rent_rates
  /// 9. electricity_config
  /// 10. tenancies row itself
  static Future<TenancyActionOutcome> deleteTenancyPermanently(String tenancyId) async {
    final client = Supabase.instance.client;

    // 1. Gather all child record IDs
    final advRows = await client
        .from('tenant_advances')
        .select('id')
        .eq('tenancy_id', tenancyId);
    final advanceIds = (advRows as List)
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();

    final chargeRows = await client
        .from('charges')
        .select('id')
        .eq('tenancy_id', tenancyId);
    final chargeIds = (chargeRows as List)
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();

    final paymentRows = await client
        .from('payments')
        .select('id')
        .eq('tenancy_id', tenancyId);
    final paymentIds = (paymentRows as List)
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();

    // 2. Delete advance_transactions referencing advance_id or charge_id
    for (final aId in advanceIds) {
      await client.from('advance_transactions').delete().eq('advance_id', aId);
    }
    for (final cId in chargeIds) {
      await client.from('advance_transactions').delete().eq('charge_id', cId);
    }

    // 3. Delete payment_allocations referencing payment_id or charge_id
    for (final pId in paymentIds) {
      await client.from('payment_allocations').delete().eq('payment_id', pId);
    }
    for (final cId in chargeIds) {
      await client.from('payment_allocations').delete().eq('charge_id', cId);
    }

    // 4. Clear circular self-references and meter reading references on charges
    await client.from('charges').update({
      'reversed_by': null,
      'meter_reading_id': null,
    }).eq('tenancy_id', tenancyId);

    // 5. Delete charges
    await client.from('charges').delete().eq('tenancy_id', tenancyId);

    // 6. Delete payments
    await client.from('payments').delete().eq('tenancy_id', tenancyId);

    // 7. Delete tenant_advances
    await client.from('tenant_advances').delete().eq('tenancy_id', tenancyId);

    // 8. Clear self-references on meter_readings (corrects_id)
    await client.from('meter_readings').update({
      'corrects_id': null,
    }).eq('tenancy_id', tenancyId);

    // 9. Delete meter_readings
    await client.from('meter_readings').delete().eq('tenancy_id', tenancyId);

    // 10. Delete documents
    await client.from('documents').delete().eq('tenancy_id', tenancyId);

    // 11. Delete rent_rates
    await client.from('rent_rates').delete().eq('tenancy_id', tenancyId);

    // 12. Delete electricity_config
    await client.from('electricity_config').delete().eq('tenancy_id', tenancyId);

    // 13. Delete the tenancy itself from the database
    await client.from('tenancies').delete().eq('id', tenancyId);

    return TenancyActionOutcome.deleted;
  }

  /// Permanently deletes tenancy from database (alias for backwards compatibility)
  static Future<TenancyActionOutcome> deleteOrDeactivateTenancy(String tenancyId) =>
      deleteTenancyPermanently(tenancyId);

  /// Backward compatible alias
  static Future<TenancyActionOutcome> deleteTenancy(String tenancyId) =>
      deleteTenancyPermanently(tenancyId);
}
