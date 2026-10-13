# Rentify

> Production-ready rent management platform — Android APK + Mobile-first Web App

## Quick Start

### Prerequisites
- Flutter SDK (stable channel) — [install guide](https://docs.flutter.dev/get-started/install/windows)
- A Supabase project — [create at supabase.com](https://supabase.com)
- Android Studio or VS Code with Flutter extension (for Android)

### 1 — Clone & install dependencies
```powershell
cd D:\Rentify
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2 — Set up Supabase
1. Go to [supabase.com](https://supabase.com) → New project
2. Copy your **Project URL** and **Anon public key** (not the service role key)
3. Run migrations in order against your project:
```powershell
# Using Supabase CLI (recommended)
supabase db push

# Or paste each file manually in the Supabase SQL editor:
# supabase/migrations/001_create_profiles.sql
# supabase/migrations/002_create_tenancies.sql
# supabase/migrations/003_create_charges_payments.sql
# supabase/migrations/004_create_advances_audit.sql
# supabase/migrations/005_create_indexes.sql
```
4. Deploy Edge Functions:
```powershell
supabase functions deploy create-tenant
supabase functions deploy record-payment
supabase functions deploy run-billing
```

### 3 — Run the web app (development)
```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### 4 — Run on Android device/emulator
```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

---

## Build for Production

### Web (mobile-compatible)
```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```
Output: `build/web/` — deploy to Cloudflare Pages, Firebase Hosting, or any static host.

### Android APK (sideload)
```powershell
# 1. Generate a keystore (one-time)
keytool -genkey -v -keystore rentify.keystore -alias rentify -keyalg RSA -keysize 2048 -validity 10000

# 2. Create android/key.properties (never commit this file)
# storePassword=YOUR_STORE_PASSWORD
# keyPassword=YOUR_KEY_PASSWORD
# keyAlias=rentify
# storeFile=rentify.keystore

# 3. Build
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

---

## Project Structure

```
lib/
├── core/
│   ├── config/        env.dart (compile-time constants)
│   ├── routing/       GoRouter config + route names
│   ├── theme/         Colors, typography, Material theme
│   ├── utilities/     CurrencyFormatter, Validators, DateFormatter
│   └── widgets/       Shared UI components
├── features/
│   ├── auth/          Login, forgot password, auth providers
│   ├── dashboard/     Admin dashboard screen
│   ├── tenants/       Tenant directory, create tenant
│   ├── tenant_profile/Tenant financial overview
│   ├── ledger/        Tenant ledger (tenant view)
│   ├── payments/      Record payment screen
│   ├── electricity/   Meter reading screen
│   ├── advances/      Advance/deposit management
│   ├── billing/       Billing run status
│   ├── notifications/ Notification center
│   ├── documents/     Document upload/view
│   ├── reports/       Reports and exports
│   ├── audit/         Audit trail
│   └── settings/      App settings

supabase/
├── migrations/        001–005 SQL migrations (run in order)
├── functions/         Deno Edge Functions
│   ├── create-tenant/
│   ├── record-payment/
│   └── run-billing/
```

---

## Security Model

| Principle | Implementation |
|---|---|
| No raw DB access from client | All writes go through Edge Functions or RLS-guarded reads |
| Service-role key never in app | Stays in Edge Function env vars only |
| Anon key via `--dart-define` | Never hardcoded; not in git |
| RLS on every table | All tables have `enable row level security` |
| Audit trail | Append-only `audit_logs` — no delete/update policy |
| Financial precision | All amounts stored as `bigint paise` (no floats) |
| Idempotent billing | Unique constraint on `(tenancy_id, charge_type, billing_month)` |
| HTTPS only | Android `network_security_config.xml` disables cleartext |
| Biometric unlock | `local_auth` + `flutter_secure_storage` (not SharedPreferences) |

---

## Environment Variables (GitHub Secrets for CI)

| Secret | Description |
|---|---|
| `SUPABASE_URL` | Project URL — safe to share |
| `SUPABASE_ANON_KEY` | Anon public key — safe to share |
| `KEYSTORE_BASE64` | Base64-encoded `.keystore` file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias (e.g. `rentify`) |
| `KEY_PASSWORD` | Key password |

---

## Running Tests
```powershell
flutter test                        # All tests
flutter test test/unit/             # Unit tests only
flutter test --coverage             # With coverage report
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile & Web | Flutter (stable) — single codebase |
| State management | Riverpod 2 |
| Routing | GoRouter (type-safe, deep-link) |
| Backend | Supabase (PostgreSQL + Auth + Storage) |
| API logic | Supabase Edge Functions (Deno/TypeScript) |
| Fonts | Inter via Google Fonts |
| Financial amounts | Integer paise (bigint) — no floats |
| CI/CD | GitHub Actions |
| Web hosting | Cloudflare Pages / Firebase Hosting |
