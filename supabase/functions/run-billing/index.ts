// Supabase Edge Function: run-billing
// Generates monthly rent and electricity charges for all active tenancies.
// IDEMPOTENT: uses unique(tenancy_id, charge_type, billing_month) to prevent duplicates.
// Safe to re-run: will skip already-generated charges.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Authenticate ────────────────────────────────────────────
    const authHeader = req.headers.get('authorization');
    const isCronJob = req.headers.get('x-cron-secret') === Deno.env.get('CRON_SECRET');

    if (!isCronJob && !authHeader) return errorResponse(401, 'Unauthorized');

    let actorId: string | null = null;

    if (authHeader) {
      const adminClient = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        { global: { headers: { authorization: authHeader } } }
      );
      const { data: { user } } = await adminClient.auth.getUser();
      const { data: profile } = await adminClient
        .from('profiles').select('role').eq('id', user?.id ?? '').single();
      if (profile?.role !== 'admin') return errorResponse(403, 'Admin role required');
      actorId = user?.id ?? null;
    }

    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── Determine billing month ─────────────────────────────────
    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
    const now = new Date();
    const billingMonth = body.billingMonth ??
      `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;

    // ── Check / create billing run record ────────────────────────
    const { data: existingRun } = await serviceClient
      .from('billing_runs')
      .select('id, status')
      .eq('billing_month', billingMonth)
      .single();

    if (existingRun?.status === 'running') {
      return errorResponse(409, `Billing already running for ${billingMonth}`);
    }
    if (existingRun?.status === 'completed') {
      return new Response(
        JSON.stringify({ message: `Billing already completed for ${billingMonth}`, billingRunId: existingRun.id }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Upsert billing run
    const { data: billingRun, error: runError } = await serviceClient
      .from('billing_runs')
      .upsert({
        billing_month: billingMonth,
        status: 'running',
        started_at: new Date().toISOString(),
        charges_created: 0,
        charges_skipped: 0,
        triggered_by: actorId,
      }, { onConflict: 'billing_month' })
      .select()
      .single();

    if (runError || !billingRun) return errorResponse(500, 'Failed to create billing run');

    let chargesCreated = 0;
    let chargesSkipped = 0;
    const errors: string[] = [];

    // ── Load all active tenancies ────────────────────────────────
    const { data: tenancies } = await serviceClient
      .from('tenancies')
      .select('id, start_date, end_date, is_active')
      .eq('is_active', true)
      .lte('start_date', billingMonth);

    for (const tenancy of (tenancies ?? [])) {
      // Skip if tenancy ended before this billing month
      if (tenancy.end_date && tenancy.end_date < billingMonth) {
        chargesSkipped++;
        continue;
      }

      // ── Rent charge ──────────────────────────────────────────
      const rentResult = await generateRentCharge(serviceClient, tenancy.id, billingMonth, billingRun.id, actorId);
      if (rentResult.created) chargesCreated++;
      else if (rentResult.skipped) chargesSkipped++;
      else errors.push(`Rent ${tenancy.id}: ${rentResult.error}`);

      // ── Electricity charge ───────────────────────────────────
      const elecResult = await generateElecCharge(serviceClient, tenancy.id, billingMonth, billingRun.id, actorId);
      if (elecResult.created) chargesCreated++;
      else if (elecResult.skipped) chargesSkipped++;
      else if (elecResult.error) errors.push(`Elec ${tenancy.id}: ${elecResult.error}`);
    }

    // ── Complete billing run ─────────────────────────────────────
    const finalStatus = errors.length > 0
      ? (chargesCreated > 0 ? 'partial' : 'failed')
      : 'completed';

    await serviceClient.from('billing_runs').update({
      status: finalStatus,
      completed_at: new Date().toISOString(),
      charges_created: chargesCreated,
      charges_skipped: chargesSkipped,
      error_detail: errors.length > 0 ? errors.join('; ') : null,
    }).eq('id', billingRun.id);

    // Audit log
    await serviceClient.from('audit_logs').insert({
      actor_id: actorId,
      action: 'run_billing',
      entity_type: 'billing_run',
      entity_id: billingRun.id,
      after_value: { billing_month: billingMonth, charges_created: chargesCreated, charges_skipped: chargesSkipped, status: finalStatus },
    });

    return new Response(
      JSON.stringify({ success: true, billingRunId: billingRun.id, status: finalStatus, chargesCreated, chargesSkipped, errors }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('run-billing error:', err);
    return errorResponse(500, 'Internal server error');
  }
});

async function generateRentCharge(client: any, tenancyId: string, billingMonth: string, billingRunId: string, actorId: string | null) {
  // Check if already exists (idempotency)
  const { data: existing } = await client.from('charges')
    .select('id').eq('tenancy_id', tenancyId).eq('charge_type', 'rent').eq('billing_month', billingMonth).single();
  if (existing) return { skipped: true };

  // Get effective rent rate
  const { data: rate } = await client.from('rent_rates')
    .select('amount_paise')
    .eq('tenancy_id', tenancyId)
    .lte('effective_from', billingMonth)
    .or(`effective_to.is.null,effective_to.gte.${billingMonth}`)
    .order('effective_from', { ascending: false })
    .limit(1)
    .single();

  if (!rate) return { error: 'No active rent rate found' };

  const { error } = await client.from('charges').insert({
    tenancy_id: tenancyId,
    charge_type: 'rent',
    billing_month: billingMonth,
    amount_paise: rate.amount_paise,
    status: 'pending',
    billing_run_id: billingRunId,
    created_by: actorId,
  });

  if (error) {
    // Unique constraint violation = already exists (race condition safe)
    if (error.code === '23505') return { skipped: true };
    return { error: error.message };
  }
  return { created: true };
}

async function generateElecCharge(client: any, tenancyId: string, billingMonth: string, billingRunId: string, actorId: string | null) {
  const { data: config } = await client.from('electricity_config')
    .select('mode, fixed_amount_paise').eq('tenancy_id', tenancyId).single();

  if (!config || config.mode === 'none') return { skipped: true };

  // Already exists?
  const { data: existing } = await client.from('charges')
    .select('id').eq('tenancy_id', tenancyId).eq('charge_type', 'electricity').eq('billing_month', billingMonth).single();
  if (existing) return { skipped: true };

  if (config.mode === 'fixed') {
    const { error } = await client.from('charges').insert({
      tenancy_id: tenancyId, charge_type: 'electricity', billing_month: billingMonth,
      amount_paise: config.fixed_amount_paise, status: 'pending',
      billing_run_id: billingRunId, created_by: actorId,
    });
    if (error?.code === '23505') return { skipped: true };
    return error ? { error: error.message } : { created: true };
  }

  if (config.mode === 'meter') {
    // Check for accepted meter reading this month
    const { data: reading } = await client.from('meter_readings')
      .select('id, amount_paise').eq('tenancy_id', tenancyId).eq('billing_month', billingMonth)
      .eq('is_corrected', false).single();

    if (!reading) {
      // Flag as awaiting — do NOT create a zero charge
      return { skipped: true }; // Admin will see "awaiting meter reading" in dashboard
    }

    const { error } = await client.from('charges').insert({
      tenancy_id: tenancyId, charge_type: 'electricity', billing_month: billingMonth,
      amount_paise: reading.amount_paise, status: 'pending',
      meter_reading_id: reading.id, billing_run_id: billingRunId, created_by: actorId,
    });
    if (error?.code === '23505') return { skipped: true };
    return error ? { error: error.message } : { created: true };
  }

  return { skipped: true };
}

function errorResponse(status: number, message: string) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status
  });
}
