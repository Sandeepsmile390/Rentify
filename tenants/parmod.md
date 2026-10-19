# Tenant Profile: Parmod

- **Database Tenancy ID**: `f3ee40ba-125c-422a-919f-19ad1b52cde3`
- **Tenant Name**: Parmod
- **Mobile Number**: `7033602546`
- **Unit / Room ID**: Room 5
- **Login Status**: Enabled (User ID: `7033602546`, Default Password: `7033602546`)
- **Entry / Start Date**: 31/08/2025 *(Active dataset from May 2026)*
- **Advance / Security Deposit**: ₹1,500.00 (Received on: 21/09/2025)
- **Monthly Rent**: ₹2,300.00 / month
- **Electricity Mode**: Fixed Monthly Charge (`fixed`)
- **Fixed Monthly Electricity Amount**: ₹300.00 / month (Auto-billed, no meter reading required)
- **Database Status**: **Synchronized in Supabase Database**

---

## 2. Monthly Electricity Charges (Fixed Mode: ₹300/mo)
| Month | Mode | Monthly Fixed Amount | Amount Paid | Outstanding Due | Status | Notes |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **May 2026** | Fixed | ₹300.00 | ₹300.00 | ₹0.00 | **Paid** | Paid 08/06 |
| **Jun 2026** | Fixed | ₹300.00 | ₹300.00 | ₹0.00 | **Paid** | Paid ₹200 on 06/07 + ₹100 on 05/08 |
| **Jul 2026** | Fixed | ₹300.00 | ₹300.00 | ₹0.00 | **Paid** | Paid 05/08 |
| **Aug 2026** | Fixed | ₹300.00 | ₹300.00 | ₹0.00 | **Paid** | Paid ₹200 on 24/09 + ₹100 on 09/10 |
| **Sep 2026** | Fixed | ₹300.00 | ₹100.00 | **₹200.00** | **Partial** | Paid ₹100 on 09/10; **₹200 due** |
| **Total** | | **₹1,500.00** | **₹1,300.00** | **₹200.00** | **₹200.00 Due** | Exact match with ledger |

---

## 3. Monthly Rent Charges
| Month | Rent Amount | Amount Paid | Outstanding Due | Status | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **May 2026** | ₹2,300.00 | ₹2,300.00 | ₹0.00 | **Paid** | Paid 08/06 |
| **Jun 2026** | ₹2,300.00 | ₹2,300.00 | ₹0.00 | **Paid** | Paid 06/07 |
| **Jul 2026** | ₹2,300.00 | ₹2,300.00 | ₹0.00 | **Paid** | Paid 05/08 |
| **Aug 2026** | ₹2,300.00 | ₹2,300.00 | ₹0.00 | **Paid** | Paid ₹2,000 on 11/09 + ₹300 on 24/09 |
| **Sep 2026** | ₹2,300.00 | ₹2,300.00 | ₹0.00 | **Paid** | Paid 09/10 |
| **Total** | **₹11,500.00** | **₹11,500.00** | **₹0.00** | **All Cleared** | |

---

## 4. Payment Transactions (Combined by Date)
*Aggregating same-day payments across rent and electricity into single receipts with itemized allocation:*

### Transaction 1 (Combined Same-Day)
- **Date**: 08/06/2026
- **Total Amount Paid**: **₹2,600.00**
- **Allocation Breakdown**:
  - May 2026 Rent: ₹2,300.00 (Fully cleared)
  - May 2026 Electricity: ₹300.00 (Fully cleared)
- **Status**: Cleared

### Transaction 2 (Combined Same-Day)
- **Date**: 06/07/2026
- **Total Amount Paid**: **₹2,500.00**
- **Allocation Breakdown**:
  - Jun 2026 Rent: ₹2,300.00 (Fully cleared)
  - Jun 2026 Electricity: ₹200.00 (Partial payment, ₹100 remaining)
- **Status**: Cleared

### Transaction 3 (Combined Same-Day)
- **Date**: 05/08/2026
- **Total Amount Paid**: **₹2,700.00**
- **Allocation Breakdown**:
  - Jun 2026 Electricity: ₹100.00 (Remaining balance cleared)
  - Jul 2026 Rent: ₹2,300.00 (Fully cleared)
  - Jul 2026 Electricity: ₹300.00 (Fully cleared)
- **Status**: Cleared

### Transaction 4
- **Date**: 11/09/2026
- **Total Amount Paid**: **₹2,000.00**
- **Allocation Breakdown**:
  - Aug 2026 Rent: ₹2,000.00 (Partial payment, ₹300 remaining)
- **Status**: Cleared

### Transaction 5 (Combined Same-Day)
- **Date**: 24/09/2026
- **Total Amount Paid**: **₹500.00**
- **Allocation Breakdown**:
  - Aug 2026 Rent: ₹300.00 (Remaining balance cleared)
  - Aug 2026 Electricity: ₹200.00 (Partial payment, ₹100 remaining)
- **Status**: Cleared

### Transaction 6 (Combined Same-Day)
- **Date**: 09/10/2026
- **Total Amount Paid**: **₹2,500.00**
- **Allocation Breakdown**:
  - Aug 2026 Electricity: ₹100.00 (Remaining balance cleared)
  - Sep 2026 Rent: ₹2,300.00 (Fully cleared)
  - Sep 2026 Electricity: ₹100.00 (Partial payment, ₹200 remaining due)
- **Status**: Cleared

---

## 5. Current Outstanding Summary (as of October 2026)
- **Advance Held in Deposit**: **₹1,500.00** (Received: 21/09/2025)
- **Total Rent Due**: **₹0.00** (All cleared)
- **Total Electricity Due**: **₹200.00** (Sep 2026 Electricity partial)
- **Total Outstanding Balance**: **₹200.00** *(Exact match with spreadsheet row `₹200.00` highlighted in red)*
