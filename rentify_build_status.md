# Rentify — Build & Production Status (v1.2.1)

## ✅ Flutter Web & Android Builds — PRODUCTION READY

- **Web Release**: Built successfully (`build/web`, optimized SPA).
- **Android APK Release**: Built successfully (`app-release.apk`, ~52 MB).
- **Current Version**: `1.2.1+6`

## ✅ Packages Resolved — All Dependencies Modernized

Key packages confirmed:
- `supabase_flutter` 2.15.4 (Realtime + Auth + PostgREST + Storage)
- `flutter_riverpod` 2.6.1 + `riverpod_generator`
- `go_router` 14.8.1
- `google_fonts` 6.3.2 (Inter)
- `local_auth` 2.3.0 (Biometric fingerprint & face recognition)
- `flutter_secure_storage` 9.2.4 (Encrypted credentials & biometrics)
- `intl` 0.19.0 (Indian rupee currency formatting in paise)
- `workmanager` 0.9.2 (Background periodic notification engine)
- `flutter_local_notifications` 17.2.4 (Status bar popups & heads-up alerts)

## ✅ Screens Implemented (15 of 15 Screens — 100% Complete)

| Screen | Status | Implementation Details |
|---|---|---|
| Login | ✅ Production | Biometrics, remember me, secure storage, dark/light toggle |
| Tenant Home / Ledger | ✅ Production | Live balance, breakdown, hover comment note, auto-payee UPI deep-linking |
| Record Payment | ✅ Production | Multi-month FIFO allocation, non-blocking floating button, receipt generator |
| Admin Dashboard | ✅ Production | Stale-while-revalidate cache, real-time KPI metrics, dark/light toggle |
| Tenant Directory | ✅ Production | Live search, active/inactive filters, scrollable actions bottom sheet |
| Create Tenant | ✅ Production | Advance deposit input, room / shop type, meter rate configuration |
| Tenant Profile / Details | ✅ Production | Clean terms card, accurate advance balance, zero unnecessary landlord clutter |
| Meter Reading | ✅ Production | Current/previous sub-meter kWh diffs, tariff multiplication, photo proof |
| Advance Management | ✅ Production | Ledger transactions, top-up deposits, deductions, refund tracking |
| Notification Center | ✅ Production | Category badges, mark-all-as-read, realtime push listening |
| Reports | ✅ Production | Normalized calendar months (excluding future incomplete months), tenant links |
| Settings | ✅ Production | Appearance toggle, data export/import, version updater, diagnostics |
| Billing Runs | ✅ Production | Idempotent monthly invoice generation, automated rent & electricity rollups |
| Audit Trail | ✅ Production | Full security event logging, user action tracking, timestamped records |
| Documents | ✅ Production | Private Supabase bucket storage, time-limited signed download URLs |

## ✅ Security Hardening & Zero-Leakage Architecture

- **100% RLS Enforcement**: Row Level Security enabled across all public database tables (`profiles`, `tenancies`, `charges`, `payments`, `advance_transactions`, `audit_logs`, `documents`, `system_settings`, etc., plus legacy tables).
- **Private Document Vault**: Tenant identity documents stored in private Supabase buckets with cryptographic signed URL access.
- **Biometric Security**: Biometric tokens and user sessions stored in encrypted Android Keystore / iOS Keychain via `flutter_secure_storage`.
- **UPI Deep-Linking**: Hardcoded payee name removed to allow NPCI VPA auto-detection across all UPI payment apps (GPay, PhonePe, Paytm).
- **WorkManager Background Push**: Periodic background notifications poll Supabase every 15 minutes when the app is completely closed, popping heads-up system notifications in the device status bar.
- **Zero Latency Caching**: Stale-while-revalidate in-memory cache eliminates recurring blocking loading spinners.

## 🔑 Key Architecture Decisions

- **No floats in money**: All amounts stored and computed as `bigint` paise (integer arithmetic).
- **Server-side billing**: Edge Functions only — never client-side.
- **RLS everywhere**: Zero public unauthenticated access to any tenant data.
- **Idempotent billing**: Unique constraint prevents duplicate monthly charges.
- **Service-role key never in app**: Only in secure backend environment.
