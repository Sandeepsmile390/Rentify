# Rentify — Known Limitations & Operational Constraints

**Document Version:** 1.0.0  
**Date:** October 13, 2026  

This document provides transparent, honest documentation of system boundaries, platform constraints, and third-party dependencies in the Rentify platform.

---

## 1. Third-Party Services & Operational Boundaries

### 1.1 WhatsApp Integration Architecture
- **Current Implementation:** Rentify uses the standard mobile OS URL scheme (`https://wa.me/91XXXXXXXXXX?text=...`) launched via `url_launcher`.
- **Characteristics:**
  - Zero API cost: Does not require paid WhatsApp Business Cloud API credits or Meta Developer account verification.
  - Transparent: The landlord previews the formatted message and explicitly taps Send in WhatsApp.
  - Limitation: The application cannot automatically detect if the message was delivered, read, or replied to by the recipient. It only confirms that the message was handed off to the WhatsApp application.

### 1.2 Push Notifications (FCM)
- **Current Implementation:** Full in-app notification center is active, rendering category-filtered notifications, unread badges, and mark-all-as-read actions.
- **Limitation:** Background system tray push notifications require a linked Google Firebase project (`google-services.json` on Android and APNs keys on iOS). Because external Firebase credentials are not provisioned in this repository, background push notifications are marked **BLOCKED** for production until Firebase keys are linked.

### 1.3 Database Backup Retention
- **Current Implementation:** Automated managed daily backups via Supabase PostgreSQL 17.
- **Limitation:** On standard and starter Supabase plans, Point-in-Time Recovery (PITR) and automated backup snapshots are retained for **7 days**. Long-term retention (e.g. 1–7 years for regulatory tax compliance) requires subscribing to an enterprise archiving tier or scheduling an external daily pg_dump export to an independent S3 bucket.

---

## 2. Platform & Hardware Constraints

### 2.1 Low-RAM Android Device Testing
- **Current Status:** Tested on Windows x86_64, Android x86_64 emulator, and Chrome Web desktop/mobile viewports.
- **Limitation:** Verification on a physical ultra-budget Android device (with ≤ 2 GB RAM) has not yet been physically executed in this development environment. `PERF-13` remains documented as requiring final physical hardware smoke testing.

### 2.2 Biometric Authentication
- **Current Implementation:** Supported via `local_auth` for Android and iOS devices possessing fingerprint or face recognition hardware.
- **Limitation:** Biometric unlock is not available on standard Web browsers and automatically falls back to secure password authentication.

---

## 3. Financial & Business Logic Constraints

### 3.1 Currency & Decimals
- All financial balances are tracked in **Integer Paise** (1 INR = 100 paise).
- Transactions smaller than 1 paisa (fractional paise) are not supported.

### 3.2 Billing Frequency
- Billing charges are generated on a monthly cycle normalized to the 1st day of the calendar month (`YYYY-MM-01`).
- Custom mid-month pro-rated billing intervals require manual adjustment line items.
