-- ============================================================
-- Migration 003: Meter readings, charges, payments, allocations
-- ============================================================

-- ── Billing runs ─────────────────────────────────────────────────
create table if not exists public.billing_runs (
  id              uuid primary key default gen_random_uuid(),
  billing_month   date not null,   -- first day of month: YYYY-MM-01
  status          text not null default 'running'
                    check (status in ('running', 'completed', 'failed', 'partial')),
  started_at      timestamptz,
  completed_at    timestamptz,
  charges_created int not null default 0,
  charges_skipped int not null default 0,
  error_detail    text,
  triggered_by    uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  constraint billing_month_format check (extract(day from billing_month) = 1)
);

-- At most one run per month (idempotency guard — only one may be running at a time)
create unique index billing_runs_month_running
  on public.billing_runs (billing_month)
  where status = 'running';

alter table public.billing_runs enable row level security;
create policy "Admin reads billing_runs"
  on public.billing_runs for select
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Service inserts/updates billing_runs"
  on public.billing_runs for all with check (true);

-- ── Meter readings ────────────────────────────────────────────────
create table if not exists public.meter_readings (
  id                uuid primary key default gen_random_uuid(),
  tenancy_id        uuid not null references public.tenancies(id),
  billing_month     date not null check (extract(day from billing_month) = 1),
  previous_reading  numeric(12, 2) not null check (previous_reading >= 0),
  current_reading   numeric(12, 2) not null check (current_reading >= 0),
  units_consumed    numeric(12, 2) generated always as (current_reading - previous_reading) stored,
  rate_paise        bigint not null check (rate_paise > 0),
  amount_paise      bigint not null check (amount_paise >= 0),
  is_corrected      boolean not null default false,
  corrects_id       uuid references public.meter_readings(id),
  notes             text,
  created_by        uuid references public.profiles(id),
  created_at        timestamptz not null default now(),
  constraint reading_sequence check (current_reading >= previous_reading),
  -- One accepted (non-corrected) reading per tenancy per month
  unique (tenancy_id, billing_month)
);

comment on column public.meter_readings.units_consumed is 'Computed: current - previous. Negative impossible due to constraint.';
comment on column public.meter_readings.is_corrected is 'true = this row has been superseded by a correction; do not use for billing.';

alter table public.meter_readings enable row level security;
create policy "Admin full access on meter_readings"
  on public.meter_readings for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own meter_readings"
  on public.meter_readings for select
  using (tenancy_id in (select id from public.tenancies where profile_id = auth.uid()));

-- ── Charges ───────────────────────────────────────────────────────
create table if not exists public.charges (
  id                uuid primary key default gen_random_uuid(),
  tenancy_id        uuid not null references public.tenancies(id),
  charge_type       text not null check (charge_type in ('rent', 'electricity')),
  billing_month     date not null check (extract(day from billing_month) = 1),
  amount_paise      bigint not null check (amount_paise >= 0),
  status            text not null default 'pending'
                      check (status in ('pending', 'partial', 'paid', 'waived', 'reversed')),
  meter_reading_id  uuid references public.meter_readings(id),
  billing_run_id    uuid references public.billing_runs(id),
  reversed_by       uuid references public.charges(id),
  notes             text,
  created_by        uuid references public.profiles(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- One charge per tenancy per type per month (prevents duplicate billing)
  unique (tenancy_id, charge_type, billing_month)
);

create trigger charges_updated_at
  before update on public.charges
  for each row execute function public.set_updated_at();

alter table public.charges enable row level security;
create policy "Admin full access on charges"
  on public.charges for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own charges"
  on public.charges for select
  using (tenancy_id in (select id from public.tenancies where profile_id = auth.uid()));

-- ── Payments ──────────────────────────────────────────────────────
create table if not exists public.payments (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid not null references public.tenancies(id),
  amount_paise    bigint not null check (amount_paise > 0),
  payment_date    date not null,
  method          text not null check (method in ('cash', 'online')),
  reference       text,
  notes           text,
  is_reversed     boolean not null default false,
  recorded_by     uuid references public.profiles(id),
  created_at      timestamptz not null default now()
);

comment on column public.payments.is_reversed is 'Set to true when payment is voided. Original row preserved for audit.';

alter table public.payments enable row level security;
create policy "Admin full access on payments"
  on public.payments for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own payments"
  on public.payments for select
  using (tenancy_id in (select id from public.tenancies where profile_id = auth.uid()));

-- ── Payment allocations ───────────────────────────────────────────
create table if not exists public.payment_allocations (
  id              uuid primary key default gen_random_uuid(),
  payment_id      uuid not null references public.payments(id),
  charge_id       uuid not null references public.charges(id),
  amount_paise    bigint not null check (amount_paise > 0),
  is_reversed     boolean not null default false,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  -- Prevent exact duplicate allocations
  unique (payment_id, charge_id)
);

alter table public.payment_allocations enable row level security;
create policy "Admin full access on payment_allocations"
  on public.payment_allocations for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own allocations"
  on public.payment_allocations for select
  using (
    payment_id in (
      select id from public.payments
      where tenancy_id in (
        select id from public.tenancies where profile_id = auth.uid()
      )
    )
  );

-- ── Database-level integrity views ────────────────────────────────

-- View: amount allocated to each charge (used by Edge Functions for validation)
create or replace view public.charge_allocation_totals as
select
  c.id as charge_id,
  c.tenancy_id,
  c.charge_type,
  c.billing_month,
  c.amount_paise,
  coalesce(sum(pa.amount_paise) filter (where not pa.is_reversed), 0) as allocated_paise,
  c.amount_paise - coalesce(sum(pa.amount_paise) filter (where not pa.is_reversed), 0) as outstanding_paise
from public.charges c
left join public.payment_allocations pa on pa.charge_id = c.id
group by c.id, c.tenancy_id, c.charge_type, c.billing_month, c.amount_paise;

-- View: total allocated from each payment
create or replace view public.payment_allocation_totals as
select
  p.id as payment_id,
  p.tenancy_id,
  p.amount_paise,
  coalesce(sum(pa.amount_paise) filter (where not pa.is_reversed), 0) as allocated_paise,
  p.amount_paise - coalesce(sum(pa.amount_paise) filter (where not pa.is_reversed), 0) as unallocated_paise
from public.payments p
left join public.payment_allocations pa on pa.payment_id = p.id
group by p.id, p.tenancy_id, p.amount_paise;
