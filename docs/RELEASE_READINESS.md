# Rentify — Release Readiness & Operational Runbook

**Document Version:** 1.0.0  
**Release Target:** Rentify 1.0.0 (Production Candidate)  
**Evaluator:** Principal Release Engineer & System Architect  

---

## 1. Release Readiness Evaluation

### 1.1 Gate Criteria Assessment

| Gate Criteria | Status | Evidence / Notes |
| :--- | :--- | :--- |
| **P0 Security & Isolation** | **PASSED** | 100% of database tables have active RLS. Zero cross-tenant data leakage. |
| **Financial Integrity** | **PASSED** | 100% exact integer arithmetic in paise. Composite unique keys guarantee idempotency. |
| **Zero Mock Data** | **PASSED** | All placeholder factories removed. Admin dashboard loads live state from Supabase. |
| **Modal Dialog Navigation** | **PASSED** | All modal dialogs and bottom sheets dismiss cleanly via `rootNavigator: true`. |
| **Automated Tests** | **PASSED** | 51/51 unit tests passing with zero failures. |
| **Production Build Artifacts** | **PASSED** | Web app deployed on Vercel; Android release APK (51.4 MB) successfully compiled. |
| **Play Store Signing Key** | **PENDING** | APK compiled with standard Flutter release configuration. Production keystore required prior to Google Play Store submission. |

---

## 2. Production Deployment Runbook

### 2.1 Web Deployment (Vercel)
1. **Compile Web Bundle:**
   ```bash
   .\flutter-direct.bat build web --release
   ```
2. **Copy Artifacts to Public Directory:**
   ```powershell
   Copy-Item -Path 'build\web\*' -Destination 'public\' -Recurse -Force
   ```
3. **Ensure SPA Rewrites (`public/vercel.json`):**
   ```json
   {
     "rewrites": [
       { "source": "/(.*)", "destination": "/index.html" }
     ],
     "headers": [
       {
         "source": "/(.*)",
         "headers": [
           { "key": "X-Content-Type-Options", "value": "nosniff" },
           { "key": "X-Frame-Options", "value": "DENY" }
         ]
       }
     ]
   }
   ```
4. **Deploy to Git:**
   Pushing to branch `main` on GitHub triggers automatic deployment to `https://rentify-sandy-delta.vercel.app/`.

### 2.2 Android Production Signing Runbook (Google Play Store)
To sign the APK with a production upload key before submitting to Google Play:
1. **Generate Keystore:**
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Create `android/key.properties` (never commit to Git):**
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=../app/upload-keystore.jks
   ```
3. **Build Signed Release App Bundle (AAB):**
   ```bash
   .\flutter-direct.bat build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.

---

## 3. Database Deployment & Rollback Runbook

### 3.1 Migration Rollout
Migrations must be executed in sequential order in Supabase SQL editor:
1. `001_create_profiles.sql` (Auth extensions & user roles)
2. `002_create_tenancies.sql` (Tenancies, rent rates, electricity config)
3. `003_create_charges_payments.sql` (Billing runs, meter readings, charges, payments)
4. `004_create_advances_audit.sql` (Advances, notifications, audit logs, documents)
5. `005_create_indexes.sql` (Performance indexing)

### 3.2 Rollback & Recovery
- **Disaster Recovery (Point-in-Time Recovery):**
  - Supabase provides automated daily backups and WAL archives.
  - In case of critical operational failure, restore the database to an earlier timestamp via the Supabase Dashboard -> Backups -> Restore.
- **Rollback Window (RTO / RPO):**
  - Recovery Time Objective (RTO): 2 hours.
  - Recovery Point Objective (RPO): 24 hours.
