# SHREEJI IMAGING AND DIAGNOSTICS CENTER PRIVATE LIMITED
## CYBERSECURITY & COMPLIANCE ARCHITECTURE

- **Classification**: Confidential Healthcare Operations
- **Scope**: Radiopharmaceutical Client Order Management Portal

---

### 1. Client-Wise Data Isolation
In medical imaging operations, order volumes, dosage requirements, and destination addresses are commercially sensitive and subject to clinical privacy standards.

1. **Server-Side Identity Verification**:
   - The browser never supplies `clientId` as a trusted parameter.
   - On every request, n8n extracts the authenticated `userId` and `clientId` directly from the validated session token.
   - SQL queries enforce parameterized tenancy:
     ```sql
     WHERE o.client_id = $token.clientId
     ```
2. **Horizontal Privilege Escalation Defense**:
   - If Client A queries `GET /shreeji/order?orderId=SHR-2026-000002` (belonging to Client B), the backend query filters by `client_id = $token.clientId`, returning a 404/403 response.

---

### 2. Credential Security & Password Hashing
1. **Never Plaintext**:
   - Passwords are never stored in plain text.
   - Hashed using the standard `bf` (Blowfish / bcrypt) algorithm via PostgreSQL `pgcrypto`:
     ```sql
     crypt('UserPassword', gen_salt('bf', 10))
     ```
   - Authentication queries use constant-time verification:
     ```sql
     WHERE u.password_hash = crypt($inputPassword, u.password_hash)
     ```
2. **Zero DB Secrets in Frontend**:
   - The frontend codebase contains zero database hostnames, usernames, or passwords.
   - The browser communicates exclusively with n8n Webhook APIs over HTTPS.

---

### 3. PWA Cache Security Enforcement
Standard Service Workers can inadvertently cache confidential health data on shared or public hospital terminals.

- In `sw.js`, caching is strictly restricted to static UI assets (`index.html`, `manifest.webmanifest`, app icons).
- All requests containing `/webhook`, `/api`, `token`, or `Authorization` headers bypass the cache directly to the network.

---

### 4. CORS & Network Hardening
1. **GitHub Pages Domain**:
   - In production n8n workflows, configure the `Access-Control-Allow-Origin` header to match your exact GitHub Pages origin (e.g., `https://your-org.github.io`) rather than wildcard `*`.
2. **Docker to Windows Host**:
   - n8n runs inside Docker container `n8n-telegram`.
   - PostgreSQL runs on the Windows host.
   - In n8n's PostgreSQL credentials, set the Host to `host.docker.internal` and Port to `5432`.
   - Ensure Windows Firewall permits incoming TCP traffic on port 5432 from Docker's virtual network interface (`vEthernet`).

---

### 5. Audit Logging & Soft Deletion
1. Orders are never permanently deleted from standard operational interfaces (`deleted_at TIMESTAMPTZ NULL`).
2. Status transitions generate immutable records in `shreeji_app.order_status_history`.
3. Client-initiated cancellation requires an explicit reason string and remains visible in audit reports.
