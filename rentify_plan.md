# Rentify — Architecture, Design System & Implementation Plan

> **Status:** Pre-build planning document. Approved before code is written.  
> **Last updated:** 2026-10-13  
> **Flutter channel:** Stable (latest)  
> **Backend:** Supabase (PostgreSQL + Auth + Storage + Edge Functions)

---

## 1. Figma Design Inventory

The file has **one page** ("Page 1") with **15 top-level frames**:

| # | Frame name | Type | Route (planned) |
|---|---|---|---|
| 01 | Admin dashboard (desktop) | Admin — wide | `/admin/dashboard` |
| 02 | Tenant home (mobile) | Tenant — narrow | `/tenant/home` |
| 03 | Tenant ledger & audit history | Tenant — narrow | `/tenant/ledger` |
| 04 | Record payment (mobile admin) | Admin — sheet/modal | `/admin/payments/record` |
| 05 | Notification center (mobile) | Shared | `/notifications` |
| 06 | Secure login & optional biometric | Shared | `/login` |
| 07 | Admin tenant directory (desktop) | Admin — wide | `/admin/tenants` |
| 08 | Create tenant (mobile admin) | Admin — sheet/modal | `/admin/tenants/create` |
| 09 | Tenant profile financial overview | Admin — narrow+wide | `/admin/tenants/:id` |
| 10 | Electricity meter reading | Admin — narrow | `/admin/electricity/:id` |
| 11 | Advance management | Admin — narrow | `/admin/advances/:id` |
| 12 | WhatsApp dues preview | Admin — bottom sheet | `/admin/tenants/:id/whatsapp` |
| 13 | Rate history & audit trail | Admin — narrow | `/admin/rates/:id` |
| 14 | Settings, security & backups | Shared | `/settings` |
| 15 | Developer handoff & design system | Reference only | — |

### Additional screens to implement (inferred from requirements, not in Figma)
| Screen | Route |
|---|---|
| Password reset | `/forgot-password` |
| Tenant create — success confirmation | `/admin/tenants/create/success` |
| Payment receipt / confirmation | `/admin/payments/:id/receipt` |
| Billing run status | `/admin/billing` |
| Reports & exports | `/admin/reports` |
| Document upload (tenant) | `/tenant/documents` |
| Admin document viewer | `/admin/tenants/:id/documents` |
| Tenant settings | `/tenant/settings` |
| Error / offline states | inline per screen |

---

## 2. Design System (from Figma frame 15)

### 2.1 Color Palette

```dart
// lib/core/theme/app_colors.dart
static const Color navy       = Color(0xFF1E2A3A);  // Primary sidebar / header bg
static const Color navyLight  = Color(0xFF263547);  // Secondary sidebar item hover
static const Color ink        = Color(0xFF111827);  // Primary text
static const Color inkLight   = Color(0xFF374151);  // Secondary text
static const Color canvas     = Color(0xFFF8F9FA);  // Page background
static const Color surface    = Color(0xFFFFFFFF);  // Card background
static const Color border     = Color(0xFFE5E7EB);  // Dividers / card borders

static const Color success    = Color(0xFF16A34A);  // Green — cleared / paid
static const Color successBg  = Color(0xFFF0FDF4);  // Green chip background
static const Color error      = Color(0xFFDC2626);  // Red — dues / danger
static const Color errorBg    = Color(0xFFFEF2F2);  // Red chip background
static const Color action     = Color(0xFF2563EB);  // Blue — primary CTA
static const Color actionBg   = Color(0xFFEFF6FF);  // Blue chip background
static const Color warning    = Color(0xFFD97706);  // Amber — attention
static const Color warningBg  = Color(0xFFFFFBEB);  // Amber chip background

static const Color rupeeGreen = Color(0xFF16A34A);  // ₹ amounts collected
static const Color rupeeDue   = Color(0xFFDC2626);  // ₹ amounts outstanding
```

### 2.2 Typography (Inter via Google Fonts)

| Role | Weight | Size | Line height |
|---|---|---|---|
| Display / Logo | 700 | 24 | 32 |
| Heading 1 | 700 | 20 | 28 |
| Heading 2 | 600 | 16 | 24 |
| Heading 3 | 600 | 14 | 20 |
| Body regular | 400 | 14 | 20 |
| Body medium | 500 | 14 | 20 |
| Caption | 400 | 12 | 16 |
| Caption bold | 600 | 12 | 16 |
| Currency large | 700 | 28 | 36 |
| Currency medium | 600 | 18 | 24 |

### 2.3 Spacing & Shape

```
Base unit:      4 px
Common:         8 / 12 / 16 / 24 / 32 px
Card radius:    12 px
Form radius:    10 px  (chips 20 px fully rounded)
Min tap target: 44 × 44 px
Elevation:      Cards use shadow 0 1 3 rgba(0,0,0,.08)
```

### 2.4 Navigation patterns
- **Desktop (≥ 900 px wide):** Persistent left rail (dark navy, 240 px) with icon + label items
- **Mobile (< 900 px):** Bottom navigation bar (4–5 destinations) + top app bar
- **Shared:** GoRouter with typed routes; deep-link safe; browser back/forward safe

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter Client (Android + Web)                                  │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────────────────┐ │
│  │  UI Layer│  │Feature     │  │Core: theme, routing, errors, │ │
│  │  Widgets │→ │State/Notif.│→ │networking, security          │ │
│  └──────────┘  │(Riverpod)  │  └──────────────────────────────┘ │
│                └─────┬──────┘                                    │
│                      │ Typed Repository interfaces               │
│                ┌─────▼──────┐                                    │
│                │ Data Layer │                                    │
│                │ Repos/Svcs │                                    │
│                └─────┬──────┘                                    │
└──────────────────────┼──────────────────────────────────────────┘
                       │ HTTPS / Supabase client (anon key only)
┌──────────────────────▼──────────────────────────────────────────┐
│  Supabase                                                        │
│  ┌──────────┐ ┌─────────┐ ┌────────────┐ ┌──────────────────┐  │
│  │PostgreSQL│ │  Auth   │ │  Storage   │ │ Edge Functions   │  │
│  │+ RLS     │ │(JWT)    │ │(private    │ │(privileged ops,  │  │
│  │policies  │ │         │ │ buckets)   │ │ billing cron,    │  │
│  └──────────┘ └─────────┘ └────────────┘ │ notifications)   │  │
│                                           └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Trust Boundaries
| Boundary | What crosses it | Control |
|---|---|---|
| Client → Supabase | Anon key + JWT | RLS policies on every table |
| Client → Edge Functions | JWT | Function-level auth check |
| Client → Storage | JWT | Bucket policies + signed URLs |
| Admin browser → Supabase Dashboard | Service role | Never in app |
| CI → Supabase | Migration runner token | CI secret, never in APK |

---

## 4. Database Schema

### 4.1 Migrations list (supabase/migrations/)

```
001_create_profiles.sql
002_create_tenancies.sql
003_create_rent_rates.sql
004_create_electricity_config.sql
005_create_meter_readings.sql
006_create_charges.sql
007_create_payments.sql
008_create_payment_allocations.sql
009_create_advances.sql
010_create_advance_transactions.sql
011_create_notifications.sql
012_create_audit_logs.sql
013_create_documents.sql
014_create_billing_runs.sql
015_create_backup_runs.sql
016_create_rls_policies.sql
017_create_indexes.sql
018_create_functions.sql
019_seed_roles.sql
```

### 4.2 Key table definitions

```sql
-- profiles (extends auth.users)
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null check (role in ('admin','tenant')),
  full_name   text not null,
  mobile      text,
  avatar_url  text,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- tenancies
create table tenancies (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid references profiles(id),
  unit_id        text not null,          -- "Room 01", "Shop A", etc.
  tenant_type    text not null check (tenant_type in ('room','shop')),
  start_date     date not null,
  end_date       date,
  is_active      boolean default true,
  notes          text,
  created_by     uuid references profiles(id),
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

-- rent_rates
create table rent_rates (
  id             uuid primary key default gen_random_uuid(),
  tenancy_id     uuid references tenancies(id),
  amount_paise   bigint not null check (amount_paise > 0),  -- 1 INR = 100 paise
  effective_from date not null,
  effective_to   date,
  reason         text,
  created_by     uuid references profiles(id),
  created_at     timestamptz default now(),
  -- prevent overlapping active periods:
  exclude using gist (tenancy_id with =, daterange(effective_from, effective_to) with &&)
);

-- electricity_config  (per tenancy)
create table electricity_config (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid references tenancies(id) unique,
  mode            text not null check (mode in ('meter','fixed','none')),
  fixed_amount_paise bigint,             -- only when mode=fixed
  created_by      uuid references profiles(id),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- electricity_rates (per-unit rate history)
create table electricity_rates (
  id              uuid primary key default gen_random_uuid(),
  rate_paise      bigint not null check (rate_paise > 0),
  effective_from  date not null,
  effective_to    date,
  created_by      uuid references profiles(id),
  created_at      timestamptz default now()
);

-- meter_readings
create table meter_readings (
  id               uuid primary key default gen_random_uuid(),
  tenancy_id       uuid references tenancies(id),
  billing_month    date not null,        -- first day of month (YYYY-MM-01)
  previous_reading numeric(12,2) not null,
  current_reading  numeric(12,2) not null,
  units_consumed   numeric(12,2) generated always as (current_reading - previous_reading) stored,
  rate_paise       bigint not null,
  amount_paise     bigint not null,
  is_corrected     boolean default false,
  corrects_id      uuid references meter_readings(id),
  created_by       uuid references profiles(id),
  created_at       timestamptz default now(),
  unique (tenancy_id, billing_month)     -- one accepted reading per period
);

-- charges
create table charges (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid references tenancies(id),
  charge_type     text not null check (charge_type in ('rent','electricity')),
  billing_month   date not null,
  amount_paise    bigint not null check (amount_paise >= 0),
  status          text not null default 'pending' check (status in ('pending','partial','paid','waived','reversed')),
  meter_reading_id uuid references meter_readings(id),
  billing_run_id  uuid references billing_runs(id),
  created_by      uuid references profiles(id),
  reversed_by     uuid references charges(id),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now(),
  unique (tenancy_id, charge_type, billing_month)
);

-- payments
create table payments (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid references tenancies(id),
  amount_paise    bigint not null check (amount_paise > 0),
  payment_date    date not null,
  method          text not null check (method in ('cash','online')),
  reference       text,
  notes           text,
  recorded_by     uuid references profiles(id),
  created_at      timestamptz default now()
);

-- payment_allocations
create table payment_allocations (
  id              uuid primary key default gen_random_uuid(),
  payment_id      uuid references payments(id),
  charge_id       uuid references charges(id),
  amount_paise    bigint not null check (amount_paise > 0),
  created_by      uuid references profiles(id),
  created_at      timestamptz default now()
);

-- tenant_advances
create table tenant_advances (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid references tenancies(id) unique,
  -- balance is derived, not stored directly
  created_at      timestamptz default now()
);

-- advance_transactions (append-only)
create table advance_transactions (
  id              uuid primary key default gen_random_uuid(),
  advance_id      uuid references tenant_advances(id),
  txn_type        text not null check (txn_type in ('received','applied','refunded','adjusted')),
  amount_paise    bigint not null,       -- positive = credit, negative = debit
  charge_id       uuid references charges(id),  -- only when txn_type='applied'
  reason          text,
  created_by      uuid references profiles(id),
  created_at      timestamptz default now()
);

-- notifications
create table notifications (
  id              uuid primary key default gen_random_uuid(),
  recipient_id    uuid references profiles(id),
  category        text not null,
  title           text not null,
  body            text,
  is_read         boolean default false,
  entity_type     text,
  entity_id       uuid,
  created_at      timestamptz default now()
);

-- audit_logs (append-only, never update/delete)
create table audit_logs (
  id              uuid primary key default gen_random_uuid(),
  actor_id        uuid references profiles(id),
  action          text not null,
  entity_type     text not null,
  entity_id       uuid,
  before_value    jsonb,
  after_value     jsonb,
  reason          text,
  correlation_id  uuid,
  created_at      timestamptz default now()
);

-- billing_runs
create table billing_runs (
  id              uuid primary key default gen_random_uuid(),
  billing_month   date not null unique,
  status          text not null check (status in ('running','completed','failed','partial')),
  started_at      timestamptz,
  completed_at    timestamptz,
  charges_created int default 0,
  charges_skipped int default 0,
  error_detail    text,
  triggered_by    uuid references profiles(id),
  created_at      timestamptz default now()
);

-- backup_runs
create table backup_runs (
  id              uuid primary key default gen_random_uuid(),
  status          text not null check (status in ('running','success','failed')),
  destination     text,
  started_at      timestamptz,
  completed_at    timestamptz,
  size_bytes      bigint,
  error_detail    text,
  created_at      timestamptz default now()
);

-- documents
create table documents (
  id              uuid primary key default gen_random_uuid(),
  tenancy_id      uuid references tenancies(id),
  uploader_id     uuid references profiles(id),
  doc_type        text not null check (doc_type in ('aadhaar','pan','other')),
  storage_path    text not null,
  file_size_bytes int,
  mime_type       text,
  created_at      timestamptz default now()
);
```

### 4.3 Key indexes

```sql
create index idx_tenancies_active       on tenancies(is_active);
create index idx_tenancies_profile      on tenancies(profile_id);
create index idx_charges_tenancy_month  on charges(tenancy_id, billing_month);
create index idx_charges_status         on charges(status);
create index idx_payments_tenancy       on payments(tenancy_id, payment_date desc);
create index idx_allocations_payment    on payment_allocations(payment_id);
create index idx_allocations_charge     on payment_allocations(charge_id);
create index idx_meter_tenancy_month    on meter_readings(tenancy_id, billing_month);
create index idx_notifications_recipient on notifications(recipient_id, is_read, created_at desc);
create index idx_audit_entity           on audit_logs(entity_type, entity_id, created_at desc);
create index idx_advance_txns           on advance_transactions(advance_id, created_at asc);
```

---

## 5. Row Level Security Policies

```sql
-- Deny by default (already false in PG, but explicit):
alter table profiles        enable row level security;
alter table tenancies       enable row level security;
alter table charges         enable row level security;
alter table payments        enable row level security;
alter table payment_allocations enable row level security;
alter table notifications   enable row level security;
alter table documents       enable row level security;
-- (all tables get RLS enabled)

-- PROFILES
create policy "Admin reads all profiles"
  on profiles for select using (auth.uid() in (select id from profiles where role='admin'));

create policy "Tenant reads own profile"
  on profiles for select using (auth.uid() = id);

-- TENANCIES (tenant sees own; admin sees all)
create policy "Tenant reads own tenancy"
  on tenancies for select
  using (profile_id = auth.uid());

create policy "Admin full access on tenancies"
  on tenancies for all
  using ((select role from profiles where id = auth.uid()) = 'admin');

-- CHARGES
create policy "Tenant reads own charges"
  on charges for select
  using (tenancy_id in (select id from tenancies where profile_id = auth.uid()));

create policy "Admin full access on charges"
  on charges for all
  using ((select role from profiles where id = auth.uid()) = 'admin');

-- PAYMENTS
create policy "Tenant reads own payments"
  on payments for select
  using (tenancy_id in (select id from tenancies where profile_id = auth.uid()));

create policy "Admin full access on payments"
  on payments for all
  using ((select role from profiles where id = auth.uid()) = 'admin');

-- AUDIT LOGS (append-only: no update, no delete for any role)
create policy "Admin reads audit logs" on audit_logs for select
  using ((select role from profiles where id = auth.uid()) = 'admin');
create policy "System inserts audit logs" on audit_logs for insert
  with check (true);   -- only service role can insert via trusted functions
-- no update/delete policy → effectively immutable via client

-- NOTIFICATIONS
create policy "Recipient reads own notifications"
  on notifications for select using (recipient_id = auth.uid());

create policy "Recipient updates own notifications"
  on notifications for update using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

-- DOCUMENTS
create policy "Tenant accesses own documents"
  on documents for select
  using (tenancy_id in (select id from tenancies where profile_id = auth.uid()));

create policy "Admin accesses all documents"
  on documents for all
  using ((select role from profiles where id = auth.uid()) = 'admin');
```

---

## 6. Edge Functions (supabase/functions/)

| Function | Trigger | Purpose |
|---|---|---|
| `create-tenant` | HTTP POST (admin JWT) | Provision auth user + profile + tenancy atomically |
| `record-payment` | HTTP POST (admin JWT) | Validate + insert payment + allocations in one transaction |
| `post-meter-reading` | HTTP POST (admin JWT) | Validate reading, compute charge, insert both atomically |
| `run-billing` | Cron / HTTP POST (admin JWT) | Monthly charge generation, idempotent |
| `send-notification` | DB trigger / HTTP POST | Create notification records + FCM push |
| `generate-backup` | Cron / HTTP POST (admin JWT) | pg_dump export to independent storage |
| `get-signed-url` | HTTP GET (authenticated JWT) | Return short-lived signed download URL for private documents |
| `reconcile-ledger` | HTTP POST (admin JWT) | Cross-check allocations vs payments, report discrepancies |

---

## 7. Flutter Project Structure

```
d:\Rentify\
├── lib/
│   ├── app/
│   │   ├── app.dart                   # MaterialApp.router setup
│   │   └── app_providers.dart         # Root Riverpod providers
│   ├── core/
│   │   ├── config/
│   │   │   └── env.dart               # SUPABASE_URL, ANON_KEY (compile-time env)
│   │   ├── errors/
│   │   │   ├── app_error.dart         # Sealed error types
│   │   │   └── error_handler.dart
│   │   ├── networking/
│   │   │   └── supabase_client.dart   # Singleton Supabase client
│   │   ├── routing/
│   │   │   ├── app_router.dart        # GoRouter configuration
│   │   │   └── routes.dart            # Typed route names/paths
│   │   ├── security/
│   │   │   └── biometric_service.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   └── app_theme.dart         # ThemeData (Material 3)
│   │   ├── utilities/
│   │   │   ├── currency_formatter.dart  # ₹ formatting, paise ↔ rupees
│   │   │   ├── date_formatter.dart
│   │   │   └── validators.dart
│   │   └── widgets/
│   │       ├── amount_chip.dart
│   │       ├── app_button.dart
│   │       ├── app_card.dart
│   │       ├── app_dialog.dart
│   │       ├── app_snackbar.dart
│   │       ├── app_text_field.dart
│   │       ├── currency_text.dart
│   │       ├── empty_state.dart
│   │       ├── error_state.dart
│   │       ├── loading_overlay.dart
│   │       ├── responsive_layout.dart
│   │       ├── status_chip.dart
│   │       └── tenant_row.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── auth_repository.dart
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart
│   │   │   └── ui/
│   │   │       ├── login_screen.dart
│   │   │       └── forgot_password_screen.dart
│   │   ├── dashboard/
│   │   │   ├── data/
│   │   │   │   └── dashboard_repository.dart
│   │   │   ├── providers/
│   │   │   │   └── dashboard_provider.dart
│   │   │   └── ui/
│   │   │       ├── admin_dashboard_screen.dart
│   │   │       └── widgets/
│   │   ├── tenants/
│   │   │   ├── data/
│   │   │   │   └── tenant_repository.dart
│   │   │   ├── models/
│   │   │   │   ├── tenant.dart
│   │   │   │   └── tenancy.dart
│   │   │   ├── providers/
│   │   │   │   └── tenant_provider.dart
│   │   │   └── ui/
│   │   │       ├── tenant_directory_screen.dart
│   │   │       ├── create_tenant_screen.dart
│   │   │       └── widgets/
│   │   ├── tenant_profile/
│   │   │   └── ui/
│   │   │       └── tenant_profile_screen.dart
│   │   ├── ledger/
│   │   │   └── ui/
│   │   │       └── tenant_ledger_screen.dart
│   │   ├── billing/
│   │   │   ├── data/
│   │   │   │   └── billing_repository.dart
│   │   │   └── ui/
│   │   │       └── billing_screen.dart
│   │   ├── electricity/
│   │   │   └── ui/
│   │   │       └── meter_reading_screen.dart
│   │   ├── payments/
│   │   │   ├── data/
│   │   │   │   └── payment_repository.dart
│   │   │   └── ui/
│   │   │       └── record_payment_screen.dart
│   │   ├── advances/
│   │   │   └── ui/
│   │   │       └── advance_management_screen.dart
│   │   ├── notifications/
│   │   │   └── ui/
│   │   │       └── notification_center_screen.dart
│   │   ├── documents/
│   │   │   └── ui/
│   │   │       └── documents_screen.dart
│   │   ├── reports/
│   │   │   └── ui/
│   │   │       └── reports_screen.dart
│   │   ├── audit/
│   │   │   └── ui/
│   │   │       └── audit_trail_screen.dart
│   │   ├── whatsapp/
│   │   │   └── ui/
│   │   │       └── whatsapp_preview_sheet.dart
│   │   └── settings/
│   │       └── ui/
│   │           └── settings_screen.dart
│   └── data/
│       ├── models/          # Shared Dart model classes (freezed)
│       ├── repositories/    # Abstract repository interfaces
│       └── services/        # Supabase service implementations
├── supabase/
│   ├── migrations/          # Numbered SQL migration files
│   ├── functions/           # Deno Edge Functions
│   │   ├── create-tenant/
│   │   ├── record-payment/
│   │   ├── post-meter-reading/
│   │   ├── run-billing/
│   │   ├── send-notification/
│   │   ├── generate-backup/
│   │   └── get-signed-url/
│   ├── seed.sql             # Synthetic test data (no real PII)
│   └── tests/               # pgTAP database tests
├── test/
│   ├── unit/
│   │   ├── billing_engine_test.dart
│   │   ├── currency_formatter_test.dart
│   │   ├── payment_allocation_test.dart
│   │   └── advance_balance_test.dart
│   ├── widget/
│   │   ├── login_screen_test.dart
│   │   ├── dashboard_test.dart
│   │   └── tenant_directory_test.dart
│   └── integration/
│       ├── auth_flow_test.dart
│       └── payment_flow_test.dart
├── integration_test/
│   └── app_test.dart        # Full E2E with flutter_test driver
├── docs/
│   ├── architecture.md
│   ├── security.md
│   ├── threat_model.md
│   ├── backup_and_restore.md
│   ├── deployment.md
│   ├── testing.md
│   └── release_checklist.md
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── release.yml
├── .env.example             # Placeholders only — never real keys
├── pubspec.yaml
└── README.md
```

---

## 8. Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Routing
  go_router: ^14.0.0

  # Backend
  supabase_flutter: ^2.5.0

  # Code generation (models)
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # UI & fonts
  google_fonts: ^6.2.1
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0

  # Utilities
  intl: ^0.19.0                   # Date/number formatting
  image: ^4.2.0                   # Image compression
  file_picker: ^8.0.0             # Document upload
  url_launcher: ^6.3.0            # WhatsApp deep link
  local_auth: ^2.3.0              # Biometric unlock
  flutter_secure_storage: ^9.2.2  # Secure token storage
  uuid: ^4.4.0

  # Logging / observability
  logging: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.12
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.3
  flutter_lints: ^4.0.0
  mocktail: ^1.0.4
```

---

## 9. Security Checklist

- [ ] RLS enabled on every table (enforced by migration 016)
- [ ] Service-role key never in Flutter source or web bundle
- [ ] Anon key only in `--dart-define` compile-time constant, excluded from logs
- [ ] Private storage bucket — no public read policy
- [ ] Signed URLs expire in 60 seconds (documents)
- [ ] Rate limiting on Edge Functions (Supabase built-in + custom check)
- [ ] Admin creation only via `supabase functions invoke create-admin` (service role)
- [ ] Password reset via Supabase Auth email flow (no custom implementation)
- [ ] Biometric unlock uses local_auth + flutter_secure_storage (not shared preferences)
- [ ] No plaintext secrets in `.env` committed to git (`gitignore` enforced)
- [ ] Secret scanning via `gitleaks` in CI
- [ ] `flutter analyze` + `dart format --set-exit-if-changed` in CI

---

## 10. Phased Build Roadmap

### Phase 1 — Foundation (current target)
> **Goal:** Working Flutter app skeleton + DB schema + auth flow

1. Install Flutter SDK (stable)
2. `flutter create --org com.rentify --platforms android,web rentify`
3. Set up core theme, routing, error handling, Supabase client
4. Create all DB migrations (Supabase local or remote)
5. Implement Login screen (frame 06) with Supabase Auth
6. Implement responsive shell (nav rail + bottom nav)
7. Wire GoRouter with all named routes (stubs for now)
8. CI pipeline: analyze + format + unit tests

**Deliverables:** Runnable app with auth; all screens stubbed; DB migrations applied.

---

### Phase 2 — Admin core flows
> **Goal:** Admin can manage tenants, record readings, post payments

1. Admin dashboard (frame 01) with real data
2. Tenant directory (frame 07) — search, filter, paginate
3. Create tenant (frame 08) — full validation + `create-tenant` Edge Function
4. Tenant profile (frame 09) — overview with financials
5. Meter reading screen (frame 10) + `post-meter-reading` Edge Function
6. Record payment (frame 04) + `record-payment` Edge Function
7. Advance management (frame 11)
8. WhatsApp preview sheet (frame 12)
9. Rate history (frame 13)
10. Unit tests for all financial calculation logic

**Deliverables:** Admin can run a complete monthly cycle in the app.

---

### Phase 3 — Tenant-facing flows
> **Goal:** Tenants can sign in and see their account

1. Tenant home (frame 02)
2. Tenant ledger (frame 03)
3. Notification center (frame 05) — shared with admin
4. Document upload + private storage access
5. Tenant settings
6. Widget tests for tenant screens

**Deliverables:** Tenant-facing experience complete.

---

### Phase 4 — Billing engine + automation
> **Goal:** Automated monthly billing, notifications, backups

1. `run-billing` Edge Function with idempotency
2. Cron job configuration (pg_cron or Supabase cron)
3. `send-notification` function + FCM push
4. `generate-backup` function
5. Settings screen (frame 14) — billing config, backup status
6. Integration tests for billing idempotency and failure recovery

**Deliverables:** Fully automated billing and backup pipeline.

---

### Phase 5 — Reports, audit, hardening
> **Goal:** Production-ready security and reporting

1. Reports & exports screen
2. Audit trail screen
3. Security hardening: RLS policy tests, secret scanning
4. Performance optimization: lazy lists, index verification
5. Accessibility review: contrast, tap targets, semantic labels
6. E2E integration tests (complete user journeys)
7. Build signed APK + web bundle
8. Deploy web to Cloudflare Pages
9. Full documentation

**Deliverables:** Production-eligible release with all docs.

---

## 11. Missing Requirements / Open Questions

| Item | Decision needed |
|---|---|
| Supabase project URL & anon key | Owner to create project at supabase.com |
| Firebase project for FCM push | Owner to create; optional for Phase 1 |
| WhatsApp Business API | Standard deep-link for now; real API needs Meta approval + cost |
| Document encryption keys | Use Supabase managed encryption at rest for now; AES-GCM at app layer is future work |
| Backup destination | Owner to provide S3/GCS bucket or Supabase paid plan backup |
| Android keystore | Owner to generate and securely store |
| Play Store vs sideload | Sideload APK for Phase 1; AAB for Play Store in Phase 5 |
| Minimum Android version | Flutter stable supports API 21 (Android 5.0); recommend API 23+ |
| India-specific timezone | Asia/Kolkata (UTC+5:30) hardcoded in billing engine |

---

## 12. Next Immediate Steps

1. **Install Flutter SDK** — if not present, download from flutter.dev
2. **Approve this plan** — confirm you're happy with the architecture
3. **Create Supabase project** — at supabase.com, get URL + anon key
4. **Phase 1 build begins** — scaffold, theme, auth, routing

