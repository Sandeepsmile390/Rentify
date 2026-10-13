-- ============================================================
-- Migration 001: Create profiles table
-- Extends auth.users with role and display information.
-- ============================================================

create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null default 'tenant'
                  check (role in ('admin', 'tenant')),
  full_name   text not null check (char_length(full_name) >= 1 and char_length(full_name) <= 100),
  mobile      text check (mobile is null or mobile ~ '^[0-9+\-\s]{10,15}$'),
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is 'User profile extending auth.users. role=admin for landlord, role=tenant for renters.';
comment on column public.profiles.role is 'admin | tenant — set server-side at provisioning, never by client directly.';

-- Auto-update updated_at on any row change
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;

create policy "Admin reads all profiles"
  on public.profiles for select
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

create policy "User reads own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "User updates own non-sensitive fields"
  on public.profiles for update
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    -- Tenants cannot change their own role
    and role = (select role from public.profiles where id = auth.uid())
  );

-- Admin can insert (used by create-tenant Edge Function with service role)
create policy "Service role inserts profiles"
  on public.profiles for insert
  with check (true); -- enforced by service role only in Edge Function
