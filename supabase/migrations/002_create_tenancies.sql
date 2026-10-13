-- ============================================================
-- Migration 002: Tenancies + electricity config + rent rates
-- ============================================================

-- ── Tenancies ────────────────────────────────────────────────────
create table if not exists public.tenancies (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid references public.profiles(id),  -- null if tenant has no login yet
  unit_id       text not null check (char_length(unit_id) between 1 and 50),
  tenant_type   text not null check (tenant_type in ('room', 'shop')),
  tenant_name   text not null,
  mobile        text,
  start_date    date not null,
  end_date      date,
  is_active     boolean not null default true,
  notes         text,
  created_by    uuid references public.profiles(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint tenancy_dates_valid check (end_date is null or end_date >= start_date)
);

comment on table public.tenancies is 'One row per tenancy period. A physical unit may have sequential tenancies.';
comment on column public.tenancies.tenant_name is 'Denormalized display name — survives even if profile is deleted.';

create trigger tenancies_updated_at
  before update on public.tenancies
  for each row execute function public.set_updated_at();

alter table public.tenancies enable row level security;

create policy "Admin full access on tenancies"
  on public.tenancies for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

create policy "Tenant reads own tenancies"
  on public.tenancies for select
  using (profile_id = auth.uid());

-- ── Rent rates ───────────────────────────────────────────────────
create extension if not exists btree_gist;

create table if not exists public.rent_rates (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid not null references public.tenancies(id),
  amount_paise    bigint not null check (amount_paise > 0),
  effective_from  date not null,
  effective_to    date,
  reason          text,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  constraint rent_rate_dates check (effective_to is null or effective_to >= effective_from),
  -- Prevent overlapping active rate periods for the same tenancy
  exclude using gist (
    tenancy_id with =,
    daterange(effective_from, effective_to, '[)') with &&
  )
);

comment on table public.rent_rates is 'Rent rate history. Changing a rate adds a new row; historical rows are immutable.';
comment on column public.rent_rates.amount_paise is 'Amount in integer paise (1 INR = 100 paise) to avoid floating-point errors.';

alter table public.rent_rates enable row level security;

create policy "Admin full access on rent_rates"
  on public.rent_rates for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

create policy "Tenant reads own rent_rates"
  on public.rent_rates for select
  using (tenancy_id in (select id from public.tenancies where profile_id = auth.uid()));

-- ── Electricity config ───────────────────────────────────────────
create table if not exists public.electricity_config (
  id                  uuid primary key default gen_random_uuid(),
  tenancy_id          uuid not null unique references public.tenancies(id),
  mode                text not null check (mode in ('meter', 'fixed', 'none')),
  fixed_amount_paise  bigint check (
    (mode = 'fixed' and fixed_amount_paise > 0)
    or (mode != 'fixed' and fixed_amount_paise is null)
  ),
  initial_reading     numeric(12, 2),  -- for meter mode only, at tenancy start
  created_by          uuid references public.profiles(id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger elec_config_updated_at
  before update on public.electricity_config
  for each row execute function public.set_updated_at();

alter table public.electricity_config enable row level security;

create policy "Admin full access on electricity_config"
  on public.electricity_config for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

create policy "Tenant reads own electricity_config"
  on public.electricity_config for select
  using (tenancy_id in (select id from public.tenancies where profile_id = auth.uid()));

-- ── Electricity rates (global per-unit rate history) ─────────────
create table if not exists public.electricity_rates (
  id              uuid primary key default gen_random_uuid(),
  rate_paise      bigint not null check (rate_paise > 0),
  effective_from  date not null,
  effective_to    date,
  reason          text,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  constraint elec_rate_dates check (effective_to is null or effective_to >= effective_from),
  exclude using gist (
    daterange(effective_from, effective_to, '[)') with &&
  )
);

-- Seed the default rate (₹9.00 per unit = 900 paise)
insert into public.electricity_rates (rate_paise, effective_from, reason)
values (900, '2020-01-01', 'Initial default rate: ₹9.00/unit')
on conflict do nothing;

alter table public.electricity_rates enable row level security;

create policy "Admin full access on electricity_rates"
  on public.electricity_rates for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

create policy "Tenant reads electricity_rates"
  on public.electricity_rates for select
  using (auth.uid() is not null);
