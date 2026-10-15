-- ============================================================
-- Migration 006: Security Definer helper functions & RLS hardening
-- Prevents recursive RLS evaluation on profiles table.
-- ============================================================

-- 1. Helper function to check admin role without recursive RLS evaluation
create or replace function public.is_admin()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

comment on function public.is_admin() is 'Security definer role checker preventing recursive RLS on profiles.';

-- 2. Lookup registered email for a tenant mobile number securely
create or replace function public.get_tenant_login_email(p_mobile text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_email text;
  v_clean text;
BEGIN
  v_clean := regexp_replace(p_mobile, '\D', '', 'g');
  IF length(v_clean) >= 10 THEN
    v_clean := right(v_clean, 10);
  END IF;

  SELECT u.email INTO v_email
  FROM public.tenancies t
  JOIN auth.users u ON u.id = t.profile_id
  WHERE t.is_active = true
    AND right(regexp_replace(coalesce(t.mobile, ''), '\D', '', 'g'), 10) = v_clean
  LIMIT 1;

  RETURN v_email;
END;
$$;

comment on function public.get_tenant_login_email(text) is 'Resolves a tenant 10-digit mobile number to their registered Supabase auth email.';

grant execute on function public.get_tenant_login_email(text) to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- 3. Admin function to create or reset tenant password directly
create or replace function public.admin_set_tenant_password(
  p_tenancy_id uuid,
  p_new_password text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_profile_id uuid;
  v_tenant_name text;
  v_mobile text;
  v_email text;
  v_clean_mobile text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can set tenant passwords';
  END IF;

  IF length(p_new_password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters';
  END IF;

  SELECT profile_id, tenant_name, mobile
  INTO v_profile_id, v_tenant_name, v_mobile
  FROM public.tenancies
  WHERE id = p_tenancy_id;

  IF v_tenant_name IS NULL THEN
    RAISE EXCEPTION 'Tenancy not found';
  END IF;

  v_clean_mobile := regexp_replace(coalesce(v_mobile, ''), '\D', '', 'g');
  IF length(v_clean_mobile) >= 10 THEN
    v_clean_mobile := right(v_clean_mobile, 10);
  END IF;

  IF v_profile_id IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE id = v_profile_id) THEN
    UPDATE auth.users
    SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
        updated_at = now()
    WHERE id = v_profile_id;

    RETURN jsonb_build_object('success', true, 'action', 'updated');
  ELSE
    v_profile_id := gen_random_uuid();
    v_email := coalesce(nullif(v_clean_mobile, ''), gen_random_uuid()::text) || '@tenant.rentify.app';

    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      is_sso_user, is_anonymous, created_at, updated_at
    ) VALUES (
      v_profile_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      v_email,
      crypt(p_new_password, gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object('role', 'tenant', 'full_name', v_tenant_name),
      false,
      false,
      now(),
      now()
    );

    INSERT INTO public.profiles (
      id, role, full_name, mobile, created_at, updated_at
    ) VALUES (
      v_profile_id, 'tenant', v_tenant_name, v_mobile, now(), now()
    ) ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name, mobile = EXCLUDED.mobile;

    UPDATE public.tenancies
    SET profile_id = v_profile_id
    WHERE id = p_tenancy_id;

    RETURN jsonb_build_object('success', true, 'action', 'created', 'email', v_email);
  END IF;
END;
$$;

grant execute on function public.admin_set_tenant_password(uuid, text) to authenticated;
