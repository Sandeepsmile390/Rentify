// Supabase Edge Function: create-tenant
// Provisions a new Supabase Auth user + profile + tenancy + electricity_config atomically.
// Called only by authenticated admins. Uses the service-role key server-side.
// The client never sees the service-role key.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface CreateTenantRequest {
  tenantName: string;
  mobile?: string;
  email?: string;           // If provided, creates a login account
  unitId: string;
  tenantType: 'room' | 'shop';
  startDate: string;        // ISO date YYYY-MM-DD
  initialRentPaise: number; // integer paise
  electricityMode: 'meter' | 'fixed' | 'none';
  fixedElecAmountPaise?: number;
  initialMeterReading?: number;
  notes?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Authenticate the calling admin ──────────────────────────
    const authHeader = req.headers.get('authorization');
    if (!authHeader) {
      return errorResponse(401, 'Missing authorization header');
    }

    // Admin client using caller's JWT (to verify they are admin)
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await adminClient.auth.getUser();
    if (authError || !user) {
      return errorResponse(401, 'Unauthenticated');
    }

    // Verify admin role from profiles table
    const { data: profile } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (profile?.role !== 'admin') {
      return errorResponse(403, 'Forbidden: admin role required');
    }

    // ── Parse and validate request body ────────────────────────
    const body: CreateTenantRequest = await req.json();

    if (!body.tenantName?.trim()) return errorResponse(400, 'tenantName is required');
    if (!body.unitId?.trim()) return errorResponse(400, 'unitId is required');
    if (!['room', 'shop'].includes(body.tenantType)) return errorResponse(400, 'Invalid tenantType');
    if (!body.startDate) return errorResponse(400, 'startDate is required');
    if (!body.initialRentPaise || body.initialRentPaise <= 0) return errorResponse(400, 'initialRentPaise must be positive');
    if (!['meter', 'fixed', 'none'].includes(body.electricityMode)) return errorResponse(400, 'Invalid electricityMode');
    if (body.electricityMode === 'fixed' && (!body.fixedElecAmountPaise || body.fixedElecAmountPaise <= 0)) {
      return errorResponse(400, 'fixedElecAmountPaise required for fixed mode');
    }

    // ── Use service-role client for privileged operations ───────
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── Create auth user if email or mobile provided ───────────
    let newUserId: string | null = null;
    const cleanMob = (body.mobile || '').replace(/\D/g, '');
    const accountEmail = body.email || (cleanMob.length >= 10 ? `${cleanMob}@tenant.rentify.app` : null);

    if (accountEmail) {
      const defaultPassword = cleanMob.length >= 6 ? cleanMob : (crypto.randomUUID().slice(0, 16) + 'Aa1!');
      const { data: newUser, error: createUserError } = await serviceClient.auth.admin.createUser({
        email: accountEmail,
        password: defaultPassword,
        email_confirm: true,
        user_metadata: { role: 'tenant', full_name: body.tenantName, mobile: body.mobile },
      });
      if (createUserError) {
        return errorResponse(400, `Failed to create user: ${createUserError.message}`);
      }
      newUserId = newUser.user.id;

      // Create profile
      const { error: profileError } = await serviceClient
        .from('profiles')
        .insert({
          id: newUserId,
          role: 'tenant',
          full_name: body.tenantName.trim(),
          mobile: body.mobile?.trim() ?? null,
        });
      if (profileError) {
        // Rollback: delete the auth user
        await serviceClient.auth.admin.deleteUser(newUserId);
        return errorResponse(500, `Failed to create profile: ${profileError.message}`);
      }

      // Send password reset so tenant can set their own password
      await serviceClient.auth.admin.generateLink({
        type: 'recovery',
        email: body.email,
      });
    }

    // ── Create tenancy record ────────────────────────────────────
    const billingMonth = body.startDate.substring(0, 8) + '01'; // YYYY-MM-01

    const { data: tenancy, error: tenancyError } = await serviceClient
      .from('tenancies')
      .insert({
        profile_id: newUserId,
        unit_id: body.unitId.trim(),
        tenant_type: body.tenantType,
        tenant_name: body.tenantName.trim(),
        mobile: body.mobile?.trim() ?? null,
        start_date: body.startDate,
        notes: body.notes?.trim() ?? null,
        created_by: user.id,
        is_active: true,
      })
      .select()
      .single();

    if (tenancyError || !tenancy) {
      if (newUserId) await serviceClient.auth.admin.deleteUser(newUserId);
      return errorResponse(500, `Failed to create tenancy: ${tenancyError?.message}`);
    }

    // ── Create initial rent rate ─────────────────────────────────
    const { error: rateError } = await serviceClient
      .from('rent_rates')
      .insert({
        tenancy_id: tenancy.id,
        amount_paise: body.initialRentPaise,
        effective_from: body.startDate,
        reason: 'Initial rent at tenancy creation',
        created_by: user.id,
      });

    if (rateError) {
      return errorResponse(500, `Failed to set rent rate: ${rateError.message}`);
    }

    // ── Create electricity config ────────────────────────────────
    const { error: elecError } = await serviceClient
      .from('electricity_config')
      .insert({
        tenancy_id: tenancy.id,
        mode: body.electricityMode,
        fixed_amount_paise: body.fixedElecAmountPaise ?? null,
        initial_reading: body.initialMeterReading ?? null,
        created_by: user.id,
      });

    if (elecError) {
      return errorResponse(500, `Failed to set electricity config: ${elecError.message}`);
    }

    // ── Create advance record ────────────────────────────────────
    await serviceClient
      .from('tenant_advances')
      .insert({ tenancy_id: tenancy.id });

    // ── Write audit log ──────────────────────────────────────────
    await serviceClient.from('audit_logs').insert({
      actor_id: user.id,
      action: 'create_tenancy',
      entity_type: 'tenancy',
      entity_id: tenancy.id,
      after_value: {
        tenancy_id: tenancy.id,
        unit_id: body.unitId,
        tenant_type: body.tenantType,
        start_date: body.startDate,
        initial_rent_paise: body.initialRentPaise,
        electricity_mode: body.electricityMode,
      },
      reason: 'Tenant created by admin',
    });

    return new Response(
      JSON.stringify({ success: true, tenancyId: tenancy.id, userId: newUserId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 201 }
    );

  } catch (err) {
    console.error('create-tenant error:', err);
    return errorResponse(500, 'Internal server error');
  }
});

function errorResponse(status: number, message: string) {
  return new Response(
    JSON.stringify({ error: message }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status }
  );
}
