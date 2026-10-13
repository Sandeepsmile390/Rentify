-- ============================================================
-- Migration 005: Indexes for performance
-- ============================================================

-- ── Tenancies ─────────────────────────────────────────────────────
create index if not exists idx_tenancies_profile
  on public.tenancies(profile_id);
create index if not exists idx_tenancies_active
  on public.tenancies(is_active) where is_active = true;
create index if not exists idx_tenancies_unit
  on public.tenancies(unit_id);

-- ── Rent rates ────────────────────────────────────────────────────
create index if not exists idx_rent_rates_tenancy
  on public.rent_rates(tenancy_id, effective_from desc);

-- ── Meter readings ─────────────────────────────────────────────────
create index if not exists idx_meter_tenancy_month
  on public.meter_readings(tenancy_id, billing_month desc);

-- ── Charges ───────────────────────────────────────────────────────
create index if not exists idx_charges_tenancy_month
  on public.charges(tenancy_id, billing_month desc);
create index if not exists idx_charges_status
  on public.charges(status) where status in ('pending', 'partial');
create index if not exists idx_charges_billing_run
  on public.charges(billing_run_id);

-- ── Payments ─────────────────────────────────────────────────────
create index if not exists idx_payments_tenancy_date
  on public.payments(tenancy_id, payment_date desc);

-- ── Payment allocations ───────────────────────────────────────────
create index if not exists idx_allocations_payment
  on public.payment_allocations(payment_id);
create index if not exists idx_allocations_charge
  on public.payment_allocations(charge_id);

-- ── Advance transactions ──────────────────────────────────────────
create index if not exists idx_advance_txns_advance
  on public.advance_transactions(advance_id, created_at asc);

-- ── Notifications ─────────────────────────────────────────────────
create index if not exists idx_notifications_recipient
  on public.notifications(recipient_id, is_read, created_at desc);

-- ── Audit logs ────────────────────────────────────────────────────
create index if not exists idx_audit_entity
  on public.audit_logs(entity_type, entity_id, created_at desc);
create index if not exists idx_audit_actor
  on public.audit_logs(actor_id, created_at desc);

-- ── Documents ────────────────────────────────────────────────────
create index if not exists idx_documents_tenancy
  on public.documents(tenancy_id) where not is_deleted;
