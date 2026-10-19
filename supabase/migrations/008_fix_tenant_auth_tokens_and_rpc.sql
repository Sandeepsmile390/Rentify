-- Migration 008: Fix tenant auth user tokens and auto-provisioning RPC
-- Prevents "Database error querying schema" in GoTrue when scanning NULL token columns

-- 1. Sanitize all existing users in auth.users
UPDATE auth.users
SET 
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  email_change = COALESCE(email_change, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  phone_change = COALESCE(phone_change, ''),
  phone_change_token = COALESCE(phone_change_token, ''),
  reauthentication_token = COALESCE(reauthentication_token, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change_token_new IS NULL
   OR email_change IS NULL
   OR phone_change IS NULL;

-- 2. Update get_tenant_login_email RPC with full non-null GoTrue token fields
CREATE OR REPLACE FUNCTION public.get_tenant_login_email(p_mobile text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_tenancy RECORD;
  v_clean text;
  v_email text;
  v_user_id uuid;
BEGIN
  -- Extract last 10 digits
  v_clean := regexp_replace(COALESCE(p_mobile, ''), '\D', '', 'g');
  IF length(v_clean) >= 10 THEN
    v_clean := right(v_clean, 10);
  END IF;

  IF length(v_clean) < 10 THEN
    RETURN NULL;
  END IF;

  -- Lookup active tenancy with portal access enabled
  SELECT t.id, t.tenant_name, t.mobile, t.profile_id, t.is_active, t.login_enabled
  INTO v_tenancy
  FROM public.tenancies t
  WHERE t.is_active = true
    AND t.login_enabled = true
    AND right(regexp_replace(COALESCE(t.mobile, ''), '\D', '', 'g'), 10) = v_clean
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF v_tenancy.id IS NULL THEN
    RETURN NULL; -- Tenancy not found or disabled
  END IF;

  -- Canonical email: <10digits>@tenant.rentify.app
  v_email := v_clean || '@tenant.rentify.app';

  -- Check if auth.users has this user
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_email;

  -- If user doesn't exist in auth.users, auto-provision user with full non-null token defaults
  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      confirmed_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change,
      email_change_token_current,
      phone_change,
      phone_change_token,
      reauthentication_token,
      raw_app_meta_data,
      raw_user_meta_data,
      is_sso_user,
      is_anonymous,
      created_at,
      updated_at
    ) VALUES (
      v_user_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt(v_clean, extensions.gen_salt('bf', 10)),
      now(),
      now(),
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object('role', 'tenant', 'full_name', v_tenancy.tenant_name),
      false,
      false,
      now(),
      now()
    );
  ELSE
    -- Ensure existing user has sanitized tokens
    UPDATE auth.users
    SET 
      confirmation_token = COALESCE(confirmation_token, ''),
      recovery_token = COALESCE(recovery_token, ''),
      email_change_token_new = COALESCE(email_change_token_new, ''),
      email_change = COALESCE(email_change, ''),
      email_change_token_current = COALESCE(email_change_token_current, ''),
      phone_change = COALESCE(phone_change, ''),
      phone_change_token = COALESCE(phone_change_token, ''),
      reauthentication_token = COALESCE(reauthentication_token, '')
    WHERE id = v_user_id;
  END IF;

  -- Ensure public.profiles has this user with role = 'tenant'
  INSERT INTO public.profiles (
    id,
    role,
    full_name,
    mobile,
    login_enabled,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    'tenant',
    v_tenancy.tenant_name,
    v_clean,
    true,
    now(),
    now()
  ) ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      mobile = EXCLUDED.mobile,
      login_enabled = true,
      updated_at = now();

  -- Link profile_id to tenancy
  UPDATE public.tenancies
  SET profile_id = v_user_id
  WHERE id = v_tenancy.id;

  RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_tenant_login_email(text) TO anon, authenticated, service_role;
