# SHREEJI CLIENT ORDER MANAGEMENT SYSTEM
### Shreeji Imaging and Diagnostics Center Private Limited

Enterprise-grade Client Order Management Web Application and PWA for Radiopharmaceutical and Diagnostic Operations.

---

## PROJECT OVERVIEW & ARCHITECTURE

```
+---------------------------------------------------------------------------------+
|                       FRONTEND: GITHUB PAGES / PWA / ANDROID                     |
|  - HTML5, CSS3, JavaScript (No direct database connections)                     |
|  - Progressive Web App (PWA) with offline UI shell & zero confidential cache    |
|  - Central API Configuration pointing to n8n Webhook APIs                       |
+---------------------------------------------------------------------------------+
                                       |
                                       | HTTPS (JSON APIs)
                                       v
+---------------------------------------------------------------------------------+
|                 BACKEND AUTOMATION: SELF-HOSTED n8n (v2.37.0)                   |
|  - Docker Container: 'n8n-telegram' on Windows PC (Port 5678)                   |
|  - Public Endpoint: https://finisher-pajamas-dipping.ngrok-free.dev/webhook    |
|  - Endpoints: Authentication, Orders, Multiple Lots, Dashboard, Admin Ledger    |
+---------------------------------------------------------------------------------+
                                       |
                                       | Parameterized SQL (Port 5432)
                                       v
+---------------------------------------------------------------------------------+
|                    DATABASE: POSTGRESQL 18.6 ('shreeji_db')                     |
|  - Host: 'host.docker.internal' (Windows host accessible from Docker)           |
|  - Schema: 'shreeji_app' (Completely isolated; preserves all existing tables)  |
|  - Tables: clients, users, products, orders, order_lots, status_history, logs   |
+---------------------------------------------------------------------------------+
```

---

## DIRECTORY STRUCTURE

```
shreeji-order-management/
├── frontend/                     # Web Application & PWA
│   ├── index.html                # Single-page responsive client portal
│   ├── manifest.webmanifest      # PWA App Manifest
│   ├── sw.js                     # Secure Service Worker (no sensitive caching)
│   └── assets/                   # App icons & branding (192px & 512px)
├── database/
│   └── schema.sql                # PostgreSQL 18.6 safe migration script (schema: shreeji_app)
├── n8n/                          # Importable n8n v2.37.0 Workflows
│   ├── authentication.json       # Login, Logout, Session Token generation
│   ├── order-management.json     # Order creation (multi-lot), order list, filters
│   ├── dashboard.json            # 8 Real-time aggregate metric cards & charts
│   └── admin.json                # Admin order ledger, status updater, audit logs
├── documentation/
│   ├── API_DOCUMENTATION.md      # Full REST/Webhook JSON API specifications
│   ├── DATABASE_DESIGN.md        # Relational ERD & entity relationship explanation
│   ├── SECURITY.md               # Cybersecurity, multi-tenant data isolation & CORS
│   └── TESTING_CHECKLIST.md      # All 20 verification tests & execution logs
└── README.md                     # Complete setup, deployment & testing guide
```

---

## STEP-BY-STEP SETUP GUIDE

### PHASE 1: POSTGRESQL DATABASE MIGRATION

#### 1. What to do:
Execute the safe schema migration in your existing PostgreSQL `shreeji_db` database.

#### 2. Where to do it:
Open **pgAdmin 4**, **DBeaver**, or the **psql** command line on your Windows PC.

#### 3. Command to run:
Connect to `shreeji_db` and execute `/database/schema.sql`:

```bash
psql -U postgres -d shreeji_db -f database/schema.sql
```
*(Or open `database/schema.sql` in pgAdmin Query Tool and click **Execute** / F5)*.

#### 4. Safety Verification:
The migration strictly creates objects inside `shreeji_app`. Pre-existing tables in the `public` schema are never touched.

#### 5. Expected Output:
```
CREATE SCHEMA
SET
CREATE EXTENSION
CREATE TABLE (clients)
CREATE TABLE (users)
CREATE TABLE (products)
CREATE SEQUENCE (order_id_seq)
CREATE TABLE (orders)
CREATE TABLE (order_lots)
CREATE TABLE (order_status_history)
INSERT 0 8 (products)
INSERT 0 3 (clients)
INSERT 0 4 (users)
```

---

### PHASE 2: CONFIGURE POSTGRESQL CREDENTIAL IN n8n

#### 1. What to do:
Configure n8n to connect to PostgreSQL running on your Windows host from inside Docker.

#### 2. Where to do it:
Open your n8n web interface:
`http://localhost:5678` 

#### 3. Settings to enter:
1. Navigate to **Credentials** → **Add Credential** → Select **Postgres**.
2. Set the following parameters:
   - **Credential Name**: `Shreeji PostgreSQL (shreeji_db)`
   - **Host**: `host.docker.internal` *(Allows Docker container `n8n-telegram` to resolve Windows host)*
   - **Database**: `shreeji_db`
   - **User**: `postgres` (or your database username)
   - **Password**: *(Your PostgreSQL password)*
   - **Port**: `5432`
   - **SSL**: `allow` or `disable`
3. Click **Test connection**.
4. Save the credential.

---

### PHASE 3: IMPORT n8n WORKFLOWS

#### 1. What to do:
Import the 4 pre-built workflow JSON files into n8n.

#### 2. Where to do it:
In n8n, click **Workflows** → **Add Workflow** (top right) → Click the `...` menu → Select **Import from File**.

#### 3. Files to import:
1. `n8n/authentication.json`
2. `n8n/order-management.json`
3. `n8n/dashboard.json`
4. `n8n/admin.json`

#### 4. Post-Import Step:
In each Postgres node inside each workflow, select your newly created credential `Shreeji PostgreSQL (shreeji_db)`. Click **Save** and toggle the workflow switch to **Active** (Active toggle in top right).

---

### PHASE 4: FRONTEND DEPLOYMENT ON GITHUB PAGES

#### 1. What to do:
Deploy the contents of the `frontend/` directory to GitHub Pages.

#### 2. Steps:
1. Initialize or push the `frontend/` directory to a GitHub repository:
   ```bash
   git add frontend/*
   git commit -m "Deploy Shreeji Client Order Management Portal"
   git push origin main
   ```
2. In GitHub, go to **Settings** → **Pages**.
3. Under **Build and deployment**, select **Deploy from a branch**.
4. Set branch to `main` and folder to `/frontend` (or root if repository root contains `index.html`).
5. Your live URL will be active at: `https://<your-username>.github.io/<repo-name>/`.

---

## DEFAULT CREDENTIALS (PRE-SEEDED)

| Role | Username | Password | Organization / Hospital |
|---|---|---|---|
| **ADMIN** | `
---

## OPERATIONAL WORKFLOW & STATUS TIMELINE

Orders progress strictly along the radiopharmaceutical lifecycle:
1. **Order Submitted**: Hospital submits order containing 1 or multiple lots.
2. **Production Planned**: Cyclotron run scheduled.
3. **Production Completed**: Synthesis & radiochemical purity verified.
4. **Invoice Generated**: Dispatch batch documentation prepared.
5. **Dispatched**: Temperature-controlled radioprotective transit.
6. **Out for Delivery**: Local courier arrives at hospital bay.
7. **Delivered**: Handed over to hospital nuclear medicine technician.
8. **Cancelled**: Audit-logged cancellation if requested.

---

## RUNNING THE 20 VERIFICATION TESTS

1. Open the application in any web browser or in the Android streaming preview.
2. Log in using any account or click the demo buttons.
3. In the top navigation bar, click the tab **"20 Verification Tests"**.
4. Click **"▶ Run All 20 Tests"**.
5. All 20 tests will execute automatically against the database and API rules, reporting green `PASSED` status badges.
