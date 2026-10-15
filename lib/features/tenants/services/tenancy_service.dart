import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenancyService {
  /// Safely and permanently deletes a tenancy and all its associated child rows.
  static Future<void> deleteTenancy(String tenancyId) async {
    final client = Supabase.instance.client;

    // 1. Delete payment allocations for payments belonging to this tenancy
    try {
      final payments = await client
          .from('payments')
          .select('id')
          .eq('tenancy_id', tenancyId);
      final pList = payments as List<dynamic>;
      for (final p in pList) {
        final pId = p['id'] as String?;
        if (pId != null) {
          await client.from('payment_allocations').delete().eq('payment_id', pId);
        }
      }
    } catch (e) {
      debugPrint('Notice deleting payment allocations (payments): $e');
    }

    // Delete payment allocations for charges belonging to this tenancy
    try {
      final charges = await client
          .from('charges')
          .select('id')
          .eq('tenancy_id', tenancyId);
      final cList = charges as List<dynamic>;
      for (final c in cList) {
        final cId = c['id'] as String?;
        if (cId != null) {
          await client.from('payment_allocations').delete().eq('charge_id', cId);
        }
      }
    } catch (e) {
      debugPrint('Notice deleting payment allocations (charges): $e');
    }

    // 2. Delete advance transactions
    try {
      await client.from('advance_transactions').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting advance_transactions: $e');
    }

    // 3. Delete tenant_advances
    try {
      await client.from('tenant_advances').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting tenant_advances: $e');
    }

    // 4. Delete payments
    try {
      await client.from('payments').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting payments: $e');
    }

    // 5. Delete charges
    try {
      await client.from('charges').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting charges: $e');
    }

    // 6. Delete meter readings
    try {
      await client.from('meter_readings').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting meter_readings: $e');
    }

    // 7. Delete documents
    try {
      await client.from('documents').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting documents: $e');
    }

    // 8. Delete rent_rates
    try {
      await client.from('rent_rates').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting rent_rates: $e');
    }

    // 9. Delete electricity_config
    try {
      await client.from('electricity_config').delete().eq('tenancy_id', tenancyId);
    } catch (e) {
      debugPrint('Notice deleting electricity_config: $e');
    }

    // 10. Fetch profile_id before deleting tenancy
    String? profileId;
    try {
      final tenancy = await client
          .from('tenancies')
          .select('profile_id')
          .eq('id', tenancyId)
          .maybeSingle();
      if (tenancy != null) {
        profileId = tenancy['profile_id'] as String?;
      }
    } catch (e) {
      debugPrint('Notice fetching profile_id: $e');
    }

    // 11. Delete the tenancy itself
    await client.from('tenancies').delete().eq('id', tenancyId);

    // 12. If tenant profile exists, clean up if no other active tenancies reference it
    if (profileId != null) {
      try {
        final others = await client
            .from('tenancies')
            .select('id')
            .eq('profile_id', profileId);
        if ((others as List).isEmpty) {
          await client.from('profiles').delete().eq('id', profileId);
        }
      } catch (e) {
        debugPrint('Notice cleaning up tenant profile: $e');
      }
    }
  }
}
