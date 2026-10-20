# Tenant Profile: Umesh

- **Database Tenancy ID**: `741b6e68-07cb-4b47-b892-0fbc35851457`
- **Tenant Name**: Umesh
- **Mobile Number**: `8015051844`
- **Unit / Room ID**: Room 10
- **Tenant Type**: Residential Room (`room`)
- **Tenancy Status**: **Inactive / Left (`is_active = false`)**
- **Entry / Start Date**: 01/10/2025
- **Vacated / End Date**: 31/12/2025 *(Inactive after completing Dec 2025; automated billing stopped)*
- **Advance / Security Deposit**: ₹0.00
- **Monthly Market Rent**: ₹4,500.00 / month
- **Electricity Mode**: None (`none` — Not billed / no meter)
- **Database Status**: **Synchronized in Supabase Database**

---

## 2. Monthly Electricity Charges
- **Status**: Not Applicable (Mode: `none`)
- **Electricity Billed**: ₹0.00
- **Electricity Due**: ₹0.00

---

## 3. Monthly Rent Charges (Oct – Dec 2025)
| Month | Rent Amount | Amount Paid | Outstanding Due | Status | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Oct 2025** | ₹4,500.00 | ₹2,600.00 | ₹1,900.00 | **Partially Paid** | ₹500 (08/01/26) + ₹1300 (02/03/26) + ₹800 (06/04/26) |
| **Nov 2025** | ₹4,500.00 | ₹0.00 | ₹4,500.00 | **Unpaid** | Unpaid |
| **Dec 2025** | ₹4,500.00 | ₹0.00 | ₹4,500.00 | **Unpaid** | Unpaid |
| **Total** | **₹13,500.00** | **₹2,600.00** | **₹10,900.00** | **Pending Due** | Exact match with spreadsheet |

---

## 4. Payment Transactions
*Payments received against October 2025 rent:*

### Transaction 1
- **Date**: 08/01/2026
- **Total Amount Paid**: **₹500.00**
- **Allocation Breakdown**:
  - Oct 2025 Rent: ₹500.00
- **Status**: Cleared

### Transaction 2
- **Date**: 02/03/2026
- **Total Amount Paid**: **₹1,300.00**
- **Allocation Breakdown**:
  - Oct 2025 Rent: ₹1,300.00
- **Status**: Cleared

### Transaction 3
- **Date**: 06/04/2026
- **Total Amount Paid**: **₹800.00**
- **Allocation Breakdown**:
  - Oct 2025 Rent: ₹800.00
- **Status**: Cleared

---

## 5. Current Outstanding Summary
- **Advance Held in Deposit**: **₹0.00**
- **Total Rent Due**: **₹10,900.00**
  - Oct 2025 Balance: ₹1,900.00
  - Nov 2025 Balance: ₹4,500.00
  - Dec 2025 Balance: ₹4,500.00
- **Total Electricity Due**: **₹0.00** (No meter)
- **Total Outstanding Balance**: **₹10,900.00** *(Exact match with spreadsheet row `₹10,900.00`)*
- **Active / Billing State**: Inactive (`is_active: false`, `end_date: '2025-12-31'`). Billings will remain stopped while the ₹10,900.00 due remains visible under inactive/vacated dues.
