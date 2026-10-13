-- ============================================================
-- Migration 004: Advances, notifications, audit, documents, backups
-- ============================================================

-- ── Tenant advances (one per tenancy) ─────────────────────────────
create table if not exists public.tenant_advances (
  id            uuid primary key default gen_random_uuid(),
  tenancy_id    uuid not null unique references public.tenancies(id),
  created_at    timestamptz not null default now()
);

comment on table public.tenant_advances is 'Header record for advance/security deposit. Balance is derived from advance_transactions.';

alter table public.tenant_advances enable row level security;
create policy "Admin full access on tenant_advances"
  on public.tenant_advances for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own advance"
  on public.tenant_advances for select
  using (tenancy_id in (select id from public.tenancies where profile_id = auth.uid()));

-- ── Advance transactions (append-only ledger) ─────────────────────
create table if not exists public.advance_transactions (
  id              uuid primary key default gen_random_uuid(),
  advance_id      uuid not null references public.tenant_advances(id),
  txn_type        text not null check (txn_type in ('received', 'applied', 'refunded', 'adjusted')),
  amount_paise    bigint not null,   -- positive = credit (received/adjusted+), negative = debit (applied/refunded)
  charge_id       uuid references public.charges(id),  -- populated when txn_type = 'applied'
  reason          text,
  created_by      uuid references public.profiles(id),
  created_at      timestamptz not null default now(),
  constraint applied_requires_charge check (
    (txn_type = 'applied' and charge_id is not null)
    or (txn_type != 'applied')
  )
);

comment on table public.advance_transactions is 'Append-only ledger. Never delete or update. Balance = sum(amount_paise).';

alter table public.advance_transactions enable row level security;
create policy "Admin full access on advance_transactions"
  on public.advance_transactions for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own advance transactions"
  on public.advance_transactions for select
  using (
    advance_id in (
      select id from public.tenant_advances
      where tenancy_id in (select id from public.tenancies where profile_id = auth.uid())
    )
  );

-- ── Notifications ────────────────────────────────────────────────
create table if not exists public.notifications (
  id              uuid primary key default gen_random_uuid(),
  recipient_id    uuid not null references public.profiles(id),
  category        text not null,  -- 'payment', 'charge', 'meter', 'system', etc.
  title           text not null,
  body            text,
  is_read         boolean not null default false,
  entity_type     text,           -- 'payment', 'charge', 'tenancy', etc.
  entity_id       uuid,
  created_at      timestamptz not null default now()
);

alter table public.notifications enable row level security;
create policy "Recipient reads own notifications"
  on public.notifications for select
  using (recipient_id = auth.uid());
create policy "Recipient marks own notifications read"
  on public.notifications for update
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid() and is_read = true);  -- can only mark read, not unread
create policy "Service inserts notifications"
  on public.notifications for insert with check (true);

-- ── Audit logs (append-only — no update/delete policy) ───────────
create table if not exists public.audit_logs (
  id              uuid primary key default gen_random_uuid(),
  actor_id        uuid references public.profiles(id),
  action          text not null,         -- 'create_tenancy', 'record_payment', etc.
  entity_type     text not null,
  entity_id       uuid,
  before_value    jsonb,                 -- sanitised snapshot (no passwords/tokens)
  after_value     jsonb,
  reason          text,
  correlation_id  uuid,
  ip_address      text,
  created_at      timestamptz not null default now()
);

comment on table public.audit_logs is 'Append-only. No update/delete RLS policies. Written only by trusted Edge Functions.';

alter table public.audit_logs enable row level security;
create policy "Admin reads audit_logs"
  on public.audit_logs for select
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Service inserts audit_logs"
  on public.audit_logs for insert with check (true);
-- Intentionally no UPDATE or DELETE policy — immutable.

-- ── Documents (identity docs stored in private Storage) ──────────
create table if not exists public.documents (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid not null references public.tenancies(id),
  uploader_id     uuid references public.profiles(id),
  doc_type        text not null check (doc_type in ('aadhaar', 'pan', 'agreement', 'other')),
  storage_path    text not null,      -- path in private Supabase Storage bucket
  file_size_bytes int,
  mime_type       text,
  is_deleted      boolean not null default false,
  deleted_at      timestamptz,
  created_at      timestamptz not null default now()
);

alter table public.documents enable row level security;
create policy "Admin accesses all documents"
  on public.documents for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Tenant reads own documents"
  on public.documents for select
  using (
    tenancy_id in (select id from public.tenancies where profile_id = auth.uid())
    and not is_deleted
  );
create policy "Tenant inserts own documents"
  on public.documents for insert
  with check (
    tenancy_id in (select id from public.tenancies where profile_id = auth.uid())
    and uploader_id = auth.uid()
  );

-- ── Backup runs ───────────────────────────────────────────────────
create table if not exists public.backup_runs (
  id              uuid primary key default gen_random_uuid(),
  status          text not null check (status in ('running', 'success', 'failed')),
  destination     text,
  started_at      timestamptz,
  completed_at    timestamptz,
  size_bytes      bigint,
  checksum        text,
  error_detail    text,
  created_at      timestamptz not null default now()
);

alter table public.backup_runs enable row level security;
create policy "Admin reads backup_runs"
  on public.backup_runs for select
  using ((select role from public.profiles where id = auth.uid()) = 'admin');
create policy "Service inserts backup_runs"
  on public.backup_runs for all with check (true);
