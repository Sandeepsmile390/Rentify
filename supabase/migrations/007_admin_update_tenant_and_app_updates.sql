-- Migration 007: Admin update tenant details & App update broadcasts

-- 1. Ensure profiles has email and login_enabled
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS login_enabled boolean DEFAULT true;

-- 2. admin_toggle_tenant_login
CREATE OR REPLACE FUNCTION admin_toggle_tenant_login(p_tenancy_id uuid, p_enabled boolean)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_tenant_name text;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can enable or disable tenant login';
  END IF;

  SELECT profile_id, tenant_name INTO v_profile_id, v_tenant_name
  FROM public.tenancies
  WHERE id = p_tenancy_id;

  IF v_tenant_name IS NULL THEN
    RAISE EXCEPTION 'Tenancy not found';
  END IF;

  UPDATE public.tenancies
  SET login_enabled = p_enabled, updated_at = now()
  WHERE id = p_tenancy_id;

  IF v_profile_id IS NOT NULL THEN
    UPDATE public.profiles
    SET login_enabled = p_enabled, updated_at = now()
    WHERE id = v_profile_id;
  END IF;

  INSERT INTO public.audit_logs (id, actor_id, action, entity_type, entity_id, after_value, reason)
  VALUES (
    gen_random_uuid()::text,
    auth.uid(),
    CASE WHEN p_enabled THEN 'enable_tenant_login' ELSE 'disable_tenant_login' END,
    'tenancy',
    p_tenancy_id,
    jsonb_build_object('login_enabled', p_enabled, 'tenant_name', v_tenant_name),
    'Admin changed tenant portal access toggle'
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_toggle_tenant_login(uuid, boolean) TO authenticated, service_role, anon;

-- 3. admin_update_tenant_details
CREATE OR REPLACE FUNCTION admin_update_tenant_details(
  p_tenancy_id uuid,
  p_tenant_name text,
  p_mobile text,
  p_email text,
  p_unit_id text,
  p_tenant_type text,
  p_start_date date,
  p_is_active boolean,
  p_end_date date DEFAULT NULL,
  p_rent_paise bigint DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id uuid;
  v_curr_rent_paise bigint;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can update tenant details';
  END IF;

  SELECT profile_id INTO v_profile_id
  FROM public.tenancies
  WHERE id = p_tenancy_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tenancy % not found', p_tenancy_id;
  END IF;

  -- 1. Update tenancies record
  UPDATE public.tenancies
  SET
    tenant_name = TRIM(p_tenant_name),
    mobile = NULLIF(TRIM(p_mobile), ''),
    unit_id = TRIM(p_unit_id),
    tenant_type = LOWER(TRIM(p_tenant_type)),
    start_date = p_start_date,
    end_date = CASE WHEN p_is_active THEN NULL ELSE COALESCE(p_end_date, CURRENT_DATE) END,
    is_active = p_is_active,
    notes = NULLIF(TRIM(p_notes), ''),
    updated_at = now()
  WHERE id = p_tenancy_id;

  -- 2. Update linked profile if present
  IF v_profile_id IS NOT NULL THEN
    UPDATE public.profiles
    SET
      full_name = TRIM(p_tenant_name),
      mobile = NULLIF(TRIM(p_mobile), ''),
      email = NULLIF(TRIM(p_email), ''),
      updated_at = now()
    WHERE id = v_profile_id;
  END IF;

  -- 3. Update rent rate if provided and changed
  IF p_rent_paise IS NOT NULL AND p_rent_paise > 0 THEN
    SELECT amount_paise INTO v_curr_rent_paise
    FROM public.rent_rates
    WHERE tenancy_id = p_tenancy_id
    ORDER BY effective_from DESC, created_at DESC
    LIMIT 1;

    IF v_curr_rent_paise IS NULL OR v_curr_rent_paise != p_rent_paise THEN
      INSERT INTO public.rent_rates (
        tenancy_id,
        amount_paise,
        effective_from,
        created_by
      ) VALUES (
        p_tenancy_id,
        p_rent_paise,
        p_start_date,
        auth.uid()
      );
    END IF;
  END IF;

  -- 4. Audit log entry
  INSERT INTO public.audit_logs (
    id, actor_id, action, entity_type, entity_id, after_value, reason
  ) VALUES (
    gen_random_uuid()::text,
    auth.uid(),
    'update_tenant_details',
    'tenancy',
    p_tenancy_id,
    jsonb_build_object(
      'tenant_name', p_tenant_name,
      'mobile', p_mobile,
      'email', p_email,
      'unit_id', p_unit_id,
      'tenant_type', p_tenant_type,
      'is_active', p_is_active,
      'start_date', p_start_date,
      'rent_paise', p_rent_paise
    ),
    'Admin updated tenant details from Tenant Profile'
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_update_tenant_details(uuid, text, text, text, text, text, date, boolean, date, bigint, text) TO authenticated, service_role, anon;
