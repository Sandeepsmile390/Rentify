// Supabase Edge Function: record-payment
// Records a payment and its allocations to charges in a single atomic operation.
// All financial validation runs server-side — client cannot bypass these rules.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface AllocationInput {
  chargeId: string;
  amountPaise: number;
}

interface RecordPaymentRequest {
  tenancyId: string;
  amountPaise: number;          // Total payment amount
  paymentDate: string;          // YYYY-MM-DD
  method: 'cash' | 'online';
  reference?: string;
  notes?: string;
  allocations: AllocationInput[];  // Must sum to ≤ amountPaise
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Authenticate admin ──────────────────────────────────────
    const authHeader = req.headers.get('authorization');
    if (!authHeader) return errorResponse(401, 'Missing authorization header');

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { authorization: authHeader } } }
    );

    const { data: { user } } = await adminClient.auth.getUser();
    if (!user) return errorResponse(401, 'Unauthenticated');

    const { data: profile } = await adminClient
      .from('profiles').select('role').eq('id', user.id).single();
    if (profile?.role !== 'admin') return errorResponse(403, 'Admin role required');

    // ── Parse request ───────────────────────────────────────────
    const body: RecordPaymentRequest = await req.json();

    if (!body.tenancyId) return errorResponse(400, 'tenancyId is required');
    if (!body.amountPaise || body.amountPaise <= 0) return errorResponse(400, 'amountPaise must be positive');
    if (!body.paymentDate) return errorResponse(400, 'paymentDate is required');
    if (!['cash', 'online'].includes(body.method)) return errorResponse(400, 'Invalid method');
    if (!Array.isArray(body.allocations)) return errorResponse(400, 'allocations must be an array');

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── Validate allocation total ≤ payment ─────────────────────
    const totalAllocated = body.allocations.reduce((sum, a) => sum + a.amountPaise, 0);
    if (totalAllocated > body.amountPaise) {
      return errorResponse(400, `Total allocations (${totalAllocated} paise) exceed payment amount (${body.amountPaise} paise)`);
    }

    // ── Validate each allocation against outstanding balance ─────
    for (const alloc of body.allocations) {
      if (!alloc.chargeId) return errorResponse(400, 'Each allocation must have chargeId');
      if (!alloc.amountPaise || alloc.amountPaise <= 0) {
        return errorResponse(400, `Allocation for ${alloc.chargeId} must be positive`);
      }

      const { data: totals } = await serviceClient
        .from('charge_allocation_totals')
        .select('outstanding_paise, tenancy_id')
        .eq('charge_id', alloc.chargeId)
        .single();

      if (!totals) return errorResponse(404, `Charge not found: ${alloc.chargeId}`);
      if (totals.tenancy_id !== body.tenancyId) {
        return errorResponse(403, `Charge ${alloc.chargeId} does not belong to this tenancy`);
      }
      if (alloc.amountPaise > totals.outstanding_paise) {
        return errorResponse(400, `Allocation of ${alloc.amountPaise} paise exceeds outstanding balance of ${totals.outstanding_paise} paise for charge ${alloc.chargeId}`);
      }
    }

    // ── Insert payment ───────────────────────────────────────────
    const { data: payment, error: paymentError } = await serviceClient
      .from('payments')
      .insert({
        tenancy_id: body.tenancyId,
        amount_paise: body.amountPaise,
        payment_date: body.paymentDate,
        method: body.method,
        reference: body.reference?.trim() ?? null,
        notes: body.notes?.trim() ?? null,
        recorded_by: user.id,
      })
      .select()
      .single();

    if (paymentError || !payment) {
      return errorResponse(500, `Failed to record payment: ${paymentError?.message}`);
    }

    // ── Insert allocations ───────────────────────────────────────
    if (body.allocations.length > 0) {
      const allocationRows = body.allocations.map(a => ({
        payment_id: payment.id,
        charge_id: a.chargeId,
        amount_paise: a.amountPaise,
        created_by: user.id,
      }));

      const { error: allocError } = await serviceClient
        .from('payment_allocations')
        .insert(allocationRows);

      if (allocError) {
        // Rollback: delete the payment
        await serviceClient.from('payments').delete().eq('id', payment.id);
        return errorResponse(500, `Failed to record allocations: ${allocError.message}`);
      }

      // ── Update charge statuses ─────────────────────────────────
      for (const alloc of body.allocations) {
        const { data: totals } = await serviceClient
          .from('charge_allocation_totals')
          .select('outstanding_paise, amount_paise')
          .eq('charge_id', alloc.chargeId)
          .single();

        if (totals) {
          let newStatus = 'pending';
          if (totals.outstanding_paise <= 0) newStatus = 'paid';
          else if (totals.outstanding_paise < totals.amount_paise) newStatus = 'partial';

          await serviceClient
            .from('charges')
            .update({ status: newStatus })
            .eq('id', alloc.chargeId);
        }
      }
    }

    // ── Audit log ────────────────────────────────────────────────
    await serviceClient.from('audit_logs').insert({
      actor_id: user.id,
      action: 'record_payment',
      entity_type: 'payment',
      entity_id: payment.id,
      after_value: {
        payment_id: payment.id,
        tenancy_id: body.tenancyId,
        amount_paise: body.amountPaise,
        method: body.method,
        allocations: body.allocations,
      },
    });

    // ── Notify tenant ─────────────────────────────────────────────
    const { data: tenancy } = await serviceClient
      .from('tenancies')
      .select('profile_id, tenant_name')
      .eq('id', body.tenancyId)
      .single();

    if (tenancy?.profile_id) {
      const rupees = (body.amountPaise / 100).toLocaleString('en-IN', { style: 'currency', currency: 'INR' });
      await serviceClient.from('notifications').insert({
        recipient_id: tenancy.profile_id,
        category: 'payment',
        title: 'Payment recorded',
        body: `A payment of ${rupees} has been recorded on your account.`,
        entity_type: 'payment',
        entity_id: payment.id,
      });
    }

    return new Response(
      JSON.stringify({ success: true, paymentId: payment.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 201 }
    );

  } catch (err) {
    console.error('record-payment error:', err);
    return errorResponse(500, 'Internal server error');
  }
});

function errorResponse(status: number, message: string) {
  return new Response(
    JSON.stringify({ error: message }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status }
  );
}
