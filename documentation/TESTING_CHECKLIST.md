# SHREEJI IMAGING AND DIAGNOSTICS CENTER PRIVATE LIMITED
## COMPREHENSIVE VERIFICATION TESTING CHECKLIST

This checklist documents the verification of all 20 enterprise tests required for the Shreeji Client Order Management Portal.

| Test ID | Test Description | Verification Steps | Expected Outcome | Status |
|---|---|---|---|---|
| **TEST 1** | Admin login | Authenticate with username `admin` / `Admin@Shreeji2026` via `/shreeji/auth/login`. | Returns token with `role: "ADMIN"`, grants access to Admin Panel and all client ledgers. | **PASSED** |
| **TEST 2** | Client login | Authenticate with `apex_pet` / `Apex@2026` via `/shreeji/auth/login`. | Returns token with `role: "CLIENT"`, binds session to `clientId: 1` (`HOSP-APEX`). | **PASSED** |
| **TEST 3** | Client A cannot see Client B orders | Query `/shreeji/orders` under `apex_pet` session; verify no orders for `HOSP-STERLING` appear. | Zero orders belonging to Client B are visible. Multi-tenant isolation verified. | **PASSED** |
| **TEST 4** | Create order with 1 lot | Submit new order with Product F-18 FDG and 1 lot of 100 mCi. | Generates Order ID `SHR-2026-XXXXXX` and single lot `SHR-2026-XXXXXX-L01`. | **PASSED** |
| **TEST 5** | Create order with 5 lots | Submit order with 5 distinct lots with staggered calibration times (08:00, 09:00, 10:00, etc.). | 5 child records inserted into `order_lots` with IDs `-L01` through `-L05`. | **PASSED** |
| **TEST 6** | Create order with 10 lots | Submit order with 10 lots of varying quantities. | All 10 lots validated, calculated total quantity matches sum, all 10 saved in DB. | **PASSED** |
| **TEST 7** | Unique Lot IDs | Verify all generated lot IDs across test orders. | Every lot possesses an atomic unique ID adhering to `SHR-YYYY-XXXXXX-LNN`. | **PASSED** |
| **TEST 8** | Order saved in PostgreSQL | Inspect `shreeji_app.orders` and `order_lots` records. | Data types (DATE, TIME, NUMERIC(10,2)) and foreign keys strictly validated. | **PASSED** |
| **TEST 9** | Order history refresh | Reload client portal or trigger `/shreeji/orders`. | Persisted orders load dynamically without data loss. | **PASSED** |
| **TEST 10** | Date filters work | Apply `From Date` and `To Date` filters on history view. | List instantly filters to orders within the selected calendar window. | **PASSED** |
| **TEST 11** | Status filters work | Filter history by `Production Planned`, `Dispatched`, etc. | Grid displays only orders matching the selected workflow state. | **PASSED** |
| **TEST 12** | Order detail displays all lots | Click "View Details" on multi-lot order. | Modal presents master order header, delivery destination, and every lot in table. | **PASSED** |
| **TEST 13** | Invalid quantity rejected | Attempt to submit lot with quantity `-5` or `0`. | Submission blocked with validation error: "Quantity must be greater than zero." | **PASSED** |
| **TEST 14** | Duplicate submission prevented | Trigger "Submit Order"; verify button state. | Button is disabled and labeled "Submitting..." until API response resolves. | **PASSED** |
| **TEST 15** | Modification request recorded | Request change on order after status advanced past 'Order Submitted'. | Informs client that direct change is restricted and logs modification request. | **PASSED** |
| **TEST 16** | Cancelled orders in audit history | Cancel an active order with confirmation prompt. | Status updates to `Cancelled`; record and status history remain intact for auditing. | **PASSED** |
| **TEST 17** | Mobile responsive layout | Test viewport at 360px, 480px, 768px, and 1280px. | Header wraps cleanly, tables scroll horizontally, cards adapt into single-column. | **PASSED** |
| **TEST 18** | PWA installation | Inspect `manifest.webmanifest` and `sw.js` registration. | Manifest validated, standalone display configured, service worker registered. | **PASSED** |
| **TEST 19** | Unauthenticated access rejected | Send GET request to `/shreeji/dashboard` without Bearer token. | Returns `401 Unauthorized` response. | **PASSED** |
| **TEST 20** | Zero credentials in frontend | Search client HTML/JS files for database passwords. | No PostgreSQL passwords, connection strings, or master secret keys exposed. | **PASSED** |

---

### Built-in Interactive Test Runner
The application includes a built-in automated test suite accessible from the navigation tab **"20 Verification Tests"**. Clicking **"Run All 20 Tests"** executes each test scenario sequentially, displaying live status badges and execution logs.
