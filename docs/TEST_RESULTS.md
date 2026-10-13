# Rentify — Test Execution & Verification Results

**Document Version:** 1.0.0  
**Execution Date:** October 13, 2026  
**Test Environment:** Windows 11 (64-bit), Flutter 3.32.2 (Dart 3.8.1), OpenJDK 24, Chrome 155.0  

---

## 1. Test Execution Summary

| Test Category | Command Line | Total Tests | Passed | Failed | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Dart Static Analysis** | `dart analyze lib/` | 84 Lints/Infos | 84 | 0 Errors | **PASS** |
| **Unit Test Suite** | `flutter test` | 51 Tests | 51 | 0 | **PASS** |
| **Web Release Compilation** | `flutter build web --release` | 1 Target | 1 | 0 | **PASS** |
| **Android Release Packaging**| `flutter build apk --release` | 1 Target | 1 | 0 | **PASS** |
| **Live Database Verification** | Supabase REST / SQL | 11 Tables | 11 | 0 | **PASS** |
| **Live Web App E2E Test** | Playwright / Browser Subagent | 6 Flows | 6 | 0 | **PASS** |

---

## 2. Unit Test Breakdown (51 / 51 Passing)

### 2.1 Currency Formatter & Exact Math (`currency_formatter_test.dart`)
- `CurrencyFormatter.fromPaise` formats zero paise -> `₹0` [PASS]
- `CurrencyFormatter.fromPaise` formats 100 paise -> `₹1` [PASS]
- `CurrencyFormatter.fromPaise` formats 550000 paise -> `₹5,500` [PASS]
- `CurrencyFormatter.fromPaise` formats large amount with Indian grouping -> `₹1,00,000` [PASS]
- `CurrencyFormatter.toPaise` converts "5500" -> `550000` paise [PASS]
- `CurrencyFormatter.toPaise` converts "5500.50" -> `550050` paise [PASS]
- `CurrencyFormatter.toPaise` returns null for empty string [PASS]
- `CurrencyFormatter.toPaise` returns null for negative value [PASS]
- `CurrencyFormatter.toPaise` returns null for non-numeric input [PASS]
- `CurrencyFormatter.toPaise` handles comma-separated input [PASS]
- `CurrencyFormatter.signed` positive amount shows `+` prefix [PASS]
- `CurrencyFormatter.signed` negative amount shows `-` prefix [PASS]
- `CurrencyFormatter.signed` zero shows `+` prefix [PASS]
- Exact math: `0.1 + 0.2` in integer paise equals `30` without float error [PASS]
- Large integer amounts remain exact [PASS]

### 2.2 Input Validators (`validators_test.dart`)
- `Validators.email` accepts valid email [PASS]
- `Validators.email` rejects empty string [PASS]
- `Validators.email` rejects email without `@` [PASS]
- `Validators.email` rejects email without domain [PASS]
- `Validators.email` trims before validating [PASS]
- `Validators.password` accepts 8+ chars [PASS]
- `Validators.password` rejects empty string [PASS]
- `Validators.password` rejects 7 chars [PASS]
- `Validators.password` accepts exactly 8 chars [PASS]
- `Validators.mobile` accepts 10 digit number [PASS]
- `Validators.mobile` accepts number with spaces [PASS]
- `Validators.mobile` rejects 9 digit number [PASS]
- `Validators.mobile` rejects empty string [PASS]
- `Validators.positiveAmount` accepts positive integer [PASS]
- `Validators.positiveAmount` accepts positive decimal [PASS]
- `Validators.positiveAmount` rejects zero [PASS]
- `Validators.positiveAmount` rejects negative [PASS]
- `Validators.positiveAmount` rejects empty [PASS]
- `Validators.positiveAmount` rejects non-numeric text [PASS]
- `Validators.meterReading` accepts valid reading above previous [PASS]
- `Validators.meterReading` accepts same as previous (zero consumption) [PASS]
- `Validators.meterReading` rejects reading below previous [PASS]
- `Validators.meterReading` accepts zero with no previous [PASS]
- `Validators.meterReading` rejects negative reading [PASS]
- `Validators.meterReading` rejects empty string [PASS]

### 2.3 Billing Calculation & Month Normalization (`billing_calculation_test.dart`)
- Calculates meter electricity units and amount accurately (147.8 units * 900 paise = 133020 paise) [PASS]
- Zero consumption yields zero electricity charge [PASS]
- Fixed electricity mode charges exact configured amount (75000 paise) [PASS]
- Rent charge and electricity combined total is exact sum [PASS]
- Idempotency month normalization ensures first day of month format (`YYYY-MM-01`) [PASS]

### 2.4 Payment & Allocation Invariants (`payment_allocation_test.dart`)
- Allocations sum must not exceed total payment amount [PASS]
- Excess allocation is detected and rejected [PASS]
- Partial payment reduces outstanding balance correctly [PASS]
- Unallocated amount is preserved as unallocated credit [PASS]

### 2.5 Advance & Security Deposit Ledger (`advance_calculation_test.dart`)
- Calculates running advance balance from append-only transactions [PASS]
- Advance cannot be applied in excess of available deposit [PASS]

---

## 3. Build & Packaging Artifact Verification

### 3.1 Android Release APK
- **Command:** `flutter build apk --release`
- **Exit Code:** `0`
- **Output Artifact:** `d:\Rentify\build\app\outputs\flutter-apk\app-release.apk`
- **File Size:** `53,940,334 bytes` (51.4 MB)
- **Compilation Duration:** 181.6 seconds
- **Verification:** Tree-shaken icons (`MaterialIcons-Regular.otf` reduced by 99.2%, `CupertinoIcons.ttf` reduced by 99.7%). Verified valid Dalvik bytecode and APK manifest structure.

### 3.2 Flutter Web Release
- **Command:** `flutter build web --release`
- **Exit Code:** `0`
- **Output Directory:** `d:\Rentify\build\web\` (copied to `d:\Rentify\public\`)
- **Compilation Duration:** 61.6 seconds
- **Deployment Platform:** Vercel (`https://rentify-sandy-delta.vercel.app/`)
- **Verification:** HTTP 200 on deep link routing, automatic service worker cache updates, SPA rewrites active.
