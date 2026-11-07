# SHREEJI IMAGING AND DIAGNOSTICS CENTER PRIVATE LIMITED
## DATABASE DESIGN & RELATIONSHIP EXPLANATION

- **Database Engine**: PostgreSQL 18.6
- **Database Name**: `shreeji_db`
- **Application Schema**: `shreeji_app`

---

### 1. Architectural Encapsulation Rule
The `shreeji_db` database hosts pre-existing clinical and operational systems. To guarantee zero disruption:
1. All objects are strictly created inside the `shreeji_app` schema.
2. No `DROP DATABASE` or `DROP TABLE` operations are ever executed.
3. Every script uses `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and `ON CONFLICT DO NOTHING`.

---

### 2. Entity Relationship Model (ERD)

```
+--------------------+        1:N        +-------------------------+
| shreeji_app.clients|<------------------|   shreeji_app.users     |
+--------------------+                   +-------------------------+
  | id (PK)                                | id (PK)
  | client_code (UQ)                       | client_id (FK -> clients)
  | hospital_name                          | role (ADMIN / CLIENT)
  | destination_name                       | username / password_hash
  |                                        +-------------------------+
  | 1:N
  v
+--------------------+        N:1        +-------------------------+
| shreeji_app.orders |------------------>|  shreeji_app.products   |
+--------------------+                   +-------------------------+
  | id (PK, BIGINT)                        | id (PK)
  | order_id (UQ, VARCHAR)                 | product_code (UQ)
  | client_id (FK -> clients)              | name (e.g. F-18 FDG)
  | product_id (FK -> products)            | half_life_minutes (109.7)
  | order_date (DATE)                      +-------------------------+
  | submission_timestamp (TIMESTAMPTZ)
  | status (VARCHAR)
  | total_lots (INT)
  | total_quantity (NUMERIC(10,2))
  |
  +----+ 1:N
       |
       +----------------------------+
       |                            |
       v                            v
+------------------------+  +--------------------------------+
| shreeji_app.order_lots |  | shreeji_app.order_status_history|
+------------------------+  +--------------------------------+
  | id (PK, BIGINT)            | id (PK, BIGINT)
  | lot_id (UQ, VARCHAR)       | order_id (FK -> orders)
  | order_id (FK -> orders)    | previous_status
  | lot_number (INT)           | new_status
  | quantity (NUMERIC(10,2))   | updated_by (FK -> users)
  | unit (mCi / Dose)          | remarks
  | calibration_date (DATE)    | created_at (TIMESTAMPTZ)
  | calibration_time (TIME)    +--------------------------------+
+------------------------+
```

---

### 3. Detailed Table Specifications

#### Table: `shreeji_app.clients`
Stores registered hospital entities, contact persons, and delivery destination defaults.
- `id`: `SERIAL PRIMARY KEY`
- `client_code`: `VARCHAR(32) NOT NULL UNIQUE` (e.g., `'HOSP-APEX'`)
- `hospital_name`: `VARCHAR(255) NOT NULL`
- `destination_name`: `VARCHAR(255) NOT NULL`
- `is_active`: `BOOLEAN NOT NULL DEFAULT TRUE`

#### Table: `shreeji_app.users`
Credentials and role-based access control.
- `id`: `SERIAL PRIMARY KEY`
- `client_id`: `INT REFERENCES shreeji_app.clients(id)` (NULL for Central Admin)
- `username`: `VARCHAR(64) NOT NULL UNIQUE`
- `password_hash`: `VARCHAR(255) NOT NULL` (Hashed via `crypt(..., gen_salt('bf'))`)
- `role`: `VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN', 'CLIENT'))`

#### Table: `shreeji_app.products`
Radiopharmaceuticals and imaging tracers.
- `id`: `SERIAL PRIMARY KEY`
- `product_code`: `VARCHAR(32) NOT NULL UNIQUE` (e.g., `'PROD-FDG'`, `'PROD-PSMA'`)
- `name`: `VARCHAR(128) NOT NULL`
- `half_life_minutes`: `NUMERIC(8,2) DEFAULT 109.7`
- `default_unit`: `VARCHAR(10) NOT NULL DEFAULT 'mCi'`

#### Table: `shreeji_app.orders`
Master order record representing each hospital transaction.
- `id`: `BIGSERIAL PRIMARY KEY`
- `order_id`: `VARCHAR(32) NOT NULL UNIQUE` (Generated as `SHR-YYYY-XXXXXX`)
- `client_id`: `INT NOT NULL REFERENCES shreeji_app.clients(id)`
- `order_date`: `DATE NOT NULL` (Target usage date)
- `submission_timestamp`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()` (Client placement instant)
- `product_id`: `INT NOT NULL REFERENCES shreeji_app.products(id)`
- `destination`: `TEXT NOT NULL`
- `notes`: `TEXT`
- `status`: `VARCHAR(32) NOT NULL DEFAULT 'Order Submitted'`
- `total_lots`: `INT NOT NULL DEFAULT 1 CHECK (total_lots > 0)`
- `total_quantity`: `NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_quantity > 0)`

#### Table: `shreeji_app.order_lots`
Normalized child table storing individual lots under an order.
- `id`: `BIGSERIAL PRIMARY KEY`
- `lot_id`: `VARCHAR(40) NOT NULL UNIQUE` (e.g., `'SHR-2026-000001-L01'`)
- `order_id`: `BIGINT NOT NULL REFERENCES shreeji_app.orders(id) ON DELETE CASCADE`
- `lot_number`: `INT NOT NULL CHECK (lot_number > 0)`
- `quantity`: `NUMERIC(10,2) NOT NULL CHECK (quantity > 0)` (Atomic decimal accuracy)
- `unit`: `VARCHAR(10) NOT NULL CHECK (unit IN ('Dose', 'mCi'))`
- `calibration_date`: `DATE NOT NULL`
- `calibration_time`: `TIME NOT NULL`
- **Constraint**: `UNIQUE (order_id, lot_number)`

#### Table: `shreeji_app.order_status_history`
Append-only audit trail tracking every transition in the production and dispatch pipeline.
- `id`: `BIGSERIAL PRIMARY KEY`
- `order_id`: `BIGINT NOT NULL REFERENCES shreeji_app.orders(id)`
- `previous_status`: `VARCHAR(32)`
- `new_status`: `VARCHAR(32) NOT NULL`
- `updated_by`: `INT REFERENCES shreeji_app.users(id)`
- `updated_by_name`: `VARCHAR(128) NOT NULL`
- `remarks`: `TEXT`
- `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

---

### 4. Unique ID Generation Architecture
Orders use a thread-safe sequence and trigger:
```sql
CREATE SEQUENCE IF NOT EXISTS shreeji_app.order_id_seq START WITH 1 INCREMENT BY 1;

-- Format: SHR-YYYY-000001
CREATE OR REPLACE FUNCTION shreeji_app.fn_generate_order_id()
RETURNS TRIGGER AS $$
DECLARE
    curr_year TEXT;
    next_num BIGINT;
BEGIN
    IF NEW.order_id IS NULL OR NEW.order_id = '' THEN
        curr_year := TO_CHAR(CURRENT_DATE, 'YYYY');
        next_num := NEXTVAL('shreeji_app.order_id_seq');
        NEW.order_id := 'SHR-' || curr_year || '-' || LPAD(next_num::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```
For lots, the lot ID appends `-L` and a 2-digit pad (e.g. `SHR-2026-000001-L01`), preventing any ID collisions across concurrent orders.
