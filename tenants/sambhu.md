# Tenant Profile: Sambhu

- **Database Tenancy ID**: `3b7309b8-66f1-4519-aba3-e4bf3c211f1f`
- **Tenant Name**: Sambhu
- **Mobile Number**: `7765936167`
- **Unit / Room ID**: Room 7
- **Login Status**: Enabled (User ID: `7765936167`, Default Password: `7765936167`)
- **Entry / Start Date**: 23/06/2026 *(Active from June 2026)*
- **Advance / Security Deposit**: ₹0.00 *(No advance)*
- **Monthly Rent**: ₹5,000.00 / month
- **Electricity Mode**: Metered (`meter`)
- **Electricity Rate**: ₹9.00 / unit (900 paise)
- **Baseline Meter Reading**: 6,511.0 units (as of 23/06/2026)
- **Database Status**: **Synchronized in Supabase Database**

---

## 2. Monthly Electricity Consumption & Charges
| Month | Previous Reading | Current Reading | Units Consumed | Rate (₹/unit) | Electricity Cost | Amount Paid | Outstanding Due | Status | Notes |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Jun 2026** | 6,511.0 | 6,633.0 | 122.0 | ₹9.00 | ₹1,098.00 | ₹1,098.00 | ₹0.00 | **Paid** | Paid 11/07 |
| **Jul 2026** | 6,633.0 | 6,796.0 | 163.0 | ₹9.00 | ₹1,467.00 | ₹1,467.00 | ₹0.00 | **Paid** | Paid 14/08 |
| **Aug 2026** | 6,796.0 | 6,986.0 | 190.0 | ₹9.00 | ₹1,710.00 | ₹1,710.00 | ₹0.00 | **Paid** | Paid ₹1,500 on 27/09 + ₹210 on 12/10 |
| **Sep 2026** | 6,986.0 | 7,155.0 | 169.0 | ₹9.00 | ₹1,521.00 | ₹1,521.00 | ₹0.00 | **Paid** | Paid 12/10 |
| **Total** | | | **644.0 units** | | **₹5,796.00** | **₹5,796.00** | **₹0.00** | **All Cleared** | Exact match with spreadsheet |

---

## 3. Monthly Rent Charges
| Month | Rent Amount | Amount Paid | Outstanding Due | Status | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Jun 2026** | ₹5,000.00 | ₹5,000.00 | ₹0.00 | **Paid** | Paid 11/07 |
| **Jul 2026** | ₹5,000.00 | ₹5,000.00 | ₹0.00 | **Paid** | Paid ₹2,000 on 10/08 + ₹3,000 on 14/08 |
| **Aug 2026** | ₹5,000.00 | ₹5,000.00 | ₹0.00 | **Paid** | Paid ₹2,000 on 11/09 + ₹3,000 on 27/09 |
| **Sep 2026** | ₹5,000.00 | ₹0.00 | **₹5,000.00** | **Unpaid** | Unpaid in ledger (**₹5,000.00 due**) |
| **Total** | **₹20,000.00** | **₹15,000.00** | **₹5,000.00** | **₹5,000.00 Due** | Exact match with spreadsheet |

---

## 4. Payment Transactions (Combined by Date)
*Aggregating same-day payments across rent and electricity into single receipts with itemized allocation:*

### Transaction 1 (Combined Same-Day)
- **Date**: 11/07/2026
- **Total Amount Paid**: **₹6,098.00**
- **Allocation Breakdown**:
  - Jun 2026 Rent: ₹5,000.00 (Fully cleared)
  - Jun 2026 Electricity: ₹1,098.00 (Fully cleared)
- **Status**: Cleared

### Transaction 2
- **Date**: 10/08/2026
- **Total Amount Paid**: **₹2,000.00**
- **Allocation Breakdown**:
  - Jul 2026 Rent: ₹2,000.00 (Partial, ₹3,000 remaining)
- **Status**: Cleared

### Transaction 3 (Combined Same-Day)
- **Date**: 14/08/2026
- **Total Amount Paid**: **₹4,467.00**
- **Allocation Breakdown**:
  - Jul 2026 Rent: ₹3,000.00 (Remaining balance cleared)
  - Jul 2026 Electricity: ₹1,467.00 (Fully cleared)
- **Status**: Cleared

### Transaction 4
- **Date**: 11/09/2026
- **Total Amount Paid**: **₹2,000.00**
- **Allocation Breakdown**:
  - Aug 2026 Rent: ₹2,000.00 (Partial, ₹3,000 remaining)
- **Status**: Cleared

### Transaction 5 (Combined Same-Day)
- **Date**: 27/09/2026
- **Total Amount Paid**: **₹4,500.00**
- **Allocation Breakdown**:
  - Aug 2026 Rent: ₹3,000.00 (Remaining balance cleared)
  - Aug 2026 Electricity: ₹1,500.00 (Partial, ₹210 remaining)
- **Status**: Cleared

### Transaction 6 (Combined Same-Day)
- **Date**: 12/10/2026
- **Total Amount Paid**: **₹1,731.00**
- **Allocation Breakdown**:
  - Aug 2026 Electricity: ₹210.00 (Remaining balance cleared)
  - Sep 2026 Electricity: ₹1,521.00 (Fully cleared)
- **Status**: Cleared

---

## 5. Current Outstanding Summary (as of October 2026)
- **Advance Held in Deposit**: **₹0.00**
- **Total Rent Due**: **₹5,000.00** (September 2026 Rent unpaid)
- **Total Electricity Due**: **₹0.00** (All cleared)
- **Total Outstanding Balance**: **₹5,000.00** *(Exact match with spreadsheet row `₹5,000.00` highlighted in red)*
