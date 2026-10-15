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
