-- ==============================================================================
-- SHREEJI IMAGING AND DIAGNOSTICS CENTER PRIVATE LIMITED
-- CLIENT ORDER MANAGEMENT SYSTEM
-- PostgreSQL 18.6 Schema Migration & DDL
-- Target Database: shreeji_db
-- Schema Name: shreeji_app
-- ==============================================================================
-- CRITICAL SAFETY RULES:
-- 1. Does NOT drop or alter any existing database or unrelated public tables.
-- 2. Fully idempotent: safe to execute multiple times (IF NOT EXISTS / ON CONFLICT).
-- 3. All objects strictly encapsulated inside the 'shreeji_app' schema.
-- ==============================================================================

-- 1. Create Application Schema
CREATE SCHEMA IF NOT EXISTS shreeji_app;

-- Ensure schema is in search path for this session if needed
SET search_path TO shreeji_app, public;

-- Enable pgcrypto extension for secure SHA-256 / bcrypt password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Table: clients (Hospitals / Medical Diagnostic Centers)
CREATE TABLE IF NOT EXISTS shreeji_app.clients (
    id SERIAL PRIMARY KEY,
    client_code VARCHAR(32) NOT NULL UNIQUE,          -- e.g., 'HOSP-001'
    hospital_name VARCHAR(255) NOT NULL,              -- e.g., 'Apex Cancer Institute'
    contact_person VARCHAR(128) NOT NULL,
    email VARCHAR(128) NOT NULL UNIQUE,
    phone VARCHAR(32) NOT NULL,
    address TEXT NOT NULL,
    destination_name VARCHAR(255) NOT NULL,           -- Default delivery department/lab
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clients_code ON shreeji_app.clients(client_code);
CREATE INDEX IF NOT EXISTS idx_clients_email ON shreeji_app.clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_active ON shreeji_app.clients(is_active);

-- 3. Table: users (Authentication, Roles: ADMIN, CLIENT)
CREATE TABLE IF NOT EXISTS shreeji_app.users (
    id SERIAL PRIMARY KEY,
    client_id INT REFERENCES shreeji_app.clients(id) ON DELETE RESTRICT, -- NULL for Admin
    username VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(128) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,              -- Secure bcrypt or PBKDF2/SHA-256
    role VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN', 'CLIENT')),
    full_name VARCHAR(128) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    failed_login_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ NULL,
    last_login_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_username ON shreeji_app.users(username);
CREATE INDEX IF NOT EXISTS idx_users_client ON shreeji_app.users(client_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON shreeji_app.users(role);

-- 4. Table: products (Radiopharmaceuticals: F-18 FDG, PSMA, etc.)
CREATE TABLE IF NOT EXISTS shreeji_app.products (
    id SERIAL PRIMARY KEY,
    product_code VARCHAR(32) NOT NULL UNIQUE,
    name VARCHAR(128) NOT NULL,                       -- e.g., 'F-18 FDG'
    description TEXT,
    half_life_minutes NUMERIC(8,2) DEFAULT 109.7,     -- 109.7 min for F-18
    default_unit VARCHAR(10) NOT NULL DEFAULT 'mCi' CHECK (default_unit IN ('mCi', 'Dose')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_active ON shreeji_app.products(is_active);

-- 5. Sequences for Order ID Generation (e.g. SHR-2026-000001)
CREATE SEQUENCE IF NOT EXISTS shreeji_app.order_id_seq START WITH 1 INCREMENT BY 1;

-- 6. Table: orders (Header record for every hospital order)
CREATE TABLE IF NOT EXISTS shreeji_app.orders (
    id BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL UNIQUE,             -- e.g., 'SHR-2026-000001'
    client_id INT NOT NULL REFERENCES shreeji_app.clients(id) ON DELETE RESTRICT,
    order_date DATE NOT NULL,                          -- Calibration / Scheduled usage date
    submission_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- Exact time client placed order
    product_id INT NOT NULL REFERENCES shreeji_app.products(id) ON DELETE RESTRICT,
    destination TEXT NOT NULL,                         -- Hospital delivery room/department
    notes TEXT,                                        -- Special instructions
    status VARCHAR(32) NOT NULL DEFAULT 'Order Submitted'
        CHECK (status IN (
            'Order Submitted',
            'Production Planned',
            'Production Completed',
            'Invoice Generated',
            'Dispatched',
            'Out for Delivery',
            'Delivered',
            'Cancelled'
        )),
    total_lots INT NOT NULL DEFAULT 1 CHECK (total_lots > 0),
    total_quantity NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_quantity > 0),
    created_by INT REFERENCES shreeji_app.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL                        -- Soft-delete timestamp
);

CREATE INDEX IF NOT EXISTS idx_orders_client_id ON shreeji_app.orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON shreeji_app.orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status ON shreeji_app.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_product ON shreeji_app.orders(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_submission ON shreeji_app.orders(submission_timestamp);
CREATE INDEX IF NOT EXISTS idx_orders_deleted ON shreeji_app.orders(deleted_at);

-- 7. Table: order_lots (Independent lots per order)
CREATE TABLE IF NOT EXISTS shreeji_app.order_lots (
    id BIGSERIAL PRIMARY KEY,
    lot_id VARCHAR(40) NOT NULL UNIQUE,              -- e.g., 'SHR-2026-000001-L01'
    order_id BIGINT NOT NULL REFERENCES shreeji_app.orders(id) ON DELETE CASCADE,
    lot_number INT NOT NULL CHECK (lot_number > 0),
    quantity NUMERIC(10,2) NOT NULL CHECK (quantity > 0),
    unit VARCHAR(10) NOT NULL CHECK (unit IN ('Dose', 'mCi')),
    calibration_date DATE NOT NULL,
    calibration_time TIME NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'Order Submitted',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_order_lot_number UNIQUE (order_id, lot_number)
);

CREATE INDEX IF NOT EXISTS idx_order_lots_order ON shreeji_app.order_lots(order_id);
CREATE INDEX IF NOT EXISTS idx_order_lots_calib_date ON shreeji_app.order_lots(calibration_date);
CREATE INDEX IF NOT EXISTS idx_order_lots_calib_time ON shreeji_app.order_lots(calibration_time);

-- 8. Table: order_status_history (Audit timeline for state transitions)
CREATE TABLE IF NOT EXISTS shreeji_app.order_status_history (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES shreeji_app.orders(id) ON DELETE CASCADE,
    previous_status VARCHAR(32),
    new_status VARCHAR(32) NOT NULL,
    updated_by INT REFERENCES shreeji_app.users(id),
    updated_by_name VARCHAR(128) NOT NULL DEFAULT 'System',
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_status_history_order ON shreeji_app.order_status_history(order_id);

-- 9. Table: order_modification_requests (Controlled modification & cancellation)
CREATE TABLE IF NOT EXISTS shreeji_app.order_modification_requests (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES shreeji_app.orders(id) ON DELETE CASCADE,
    client_id INT NOT NULL REFERENCES shreeji_app.clients(id) ON DELETE RESTRICT,
    requested_by INT NOT NULL REFERENCES shreeji_app.users(id),
    request_type VARCHAR(20) NOT NULL CHECK (request_type IN ('MODIFICATION', 'CANCELLATION')),
    details JSONB NOT NULL,                           -- Holds requested modifications
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    admin_remarks TEXT,
    reviewed_by INT REFERENCES shreeji_app.users(id),
    reviewed_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mod_requests_order ON shreeji_app.order_modification_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_mod_requests_client ON shreeji_app.order_modification_requests(client_id);
CREATE INDEX IF NOT EXISTS idx_mod_requests_status ON shreeji_app.order_modification_requests(status);

-- 10. Table: audit_logs (Enterprise activity logging)
CREATE TABLE IF NOT EXISTS shreeji_app.audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES shreeji_app.users(id),
    client_id INT REFERENCES shreeji_app.clients(id),
    action VARCHAR(64) NOT NULL,
    entity_type VARCHAR(32) NOT NULL,
    entity_id VARCHAR(64),
    ip_address VARCHAR(45),
    user_agent TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON shreeji_app.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON shreeji_app.audit_logs(created_at);

-- 11. Table: app_settings (Configuration key-values)
CREATE TABLE IF NOT EXISTS shreeji_app.app_settings (
    setting_key VARCHAR(64) PRIMARY KEY,
    setting_value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by INT REFERENCES shreeji_app.users(id)
);

-- ==============================================================================
-- 12. Helper Function: Atomic Unique Order ID Generator
-- Format: SHR-YYYY-000001
-- ==============================================================================
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

DROP TRIGGER IF EXISTS trg_generate_order_id ON shreeji_app.orders;
CREATE TRIGGER trg_generate_order_id
BEFORE INSERT ON shreeji_app.orders
FOR EACH ROW
EXECUTE FUNCTION shreeji_app.fn_generate_order_id();

-- ==============================================================================
-- 13. Helper Function: Update Timestamp Trigger
-- ==============================================================================
CREATE OR REPLACE FUNCTION shreeji_app.fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_orders_timestamp ON shreeji_app.orders;
CREATE TRIGGER trg_update_orders_timestamp
BEFORE UPDATE ON shreeji_app.orders
FOR EACH ROW
EXECUTE FUNCTION shreeji_app.fn_update_timestamp();

-- ==============================================================================
-- 14. SEED DATA (Safe / ON CONFLICT DO NOTHING)
-- ==============================================================================

-- Products
INSERT INTO shreeji_app.products (product_code, name, description, half_life_minutes, default_unit, display_order)
VALUES
    ('PROD-FDG',   'F-18 FDG',   'Fluorodeoxyglucose (2-deoxy-2-[18F]fluoro-D-glucose) for Oncology & Neurology PET scans', 109.7, 'mCi', 1),
    ('PROD-PSMA',  'F-18 PSMA',  'Prostate-Specific Membrane Antigen PET imaging tracer', 109.7, 'mCi', 2),
    ('PROD-FDOPA', 'F-18 FDOPA', 'Fluorodopa PET imaging tracer for neuroendocrine and Parkinsonism evaluation', 109.7, 'mCi', 3),
    ('PROD-FAPI',  'F-18 FAPI',  'Fibroblast Activation Protein Inhibitor for targeted tumor stroma imaging', 109.7, 'mCi', 4),
    ('PROD-FES',   'F-18 FES',   '16a-[18F]-Fluoro-17b-estradiol for Estrogen Receptor status imaging', 109.7, 'mCi', 5),
    ('PROD-FMISO', 'F-18 FMISO', 'Fluoromisonidazole for PET assessment of tumor hypoxia', 109.7, 'mCi', 6),
    ('PROD-NOTA',  'F-18 NOTA',  'NOTA conjugated peptide PET radiotracer', 109.7, 'mCi', 7),
    ('PROD-OTHER', 'Other',      'Custom specialized radioisotope preparation / R&D synthesis', 109.7, 'mCi', 8)
ON CONFLICT (product_code) DO NOTHING;

-- Initial Clients (Hospital accounts)
INSERT INTO shreeji_app.clients (client_code, hospital_name, contact_person, email, phone, address, destination_name)
VALUES
    ('HOSP-APEX', 'Apex Cancer Hospital & Research Center', 'Dr. Rajesh Sharma', 'pet@apexhospital.org', '+91 9876543210', '120 Health City, S.G. Highway, Ahmedabad, Gujarat', 'Nuclear Medicine Dept, 1st Floor'),
    ('HOSP-STERLING', 'Sterling Diagnostic and Imaging Center', 'Mr. Amit Patel', 'orders@sterlingdiag.com', '+91 9823456781', '45 Medical Enclave, Ring Road, Surat, Gujarat', 'PET-CT Suite B'),
    ('HOSP-METRO', 'Metro Super Speciality Hospital', 'Dr. Meera Desai', 'imaging@metrohospitals.in', '+91 9811223344', '88 Care Boulevard, Vadodara, Gujarat', 'Cyclotron Delivery Bay 3')
ON CONFLICT (client_code) DO NOTHING;

-- Initial Users:
-- Admin: username 'admin', password 'Admin@Shreeji2026'
-- Clients: username 'apex_pet', password 'Apex@2026'
--          username 'sterling_pet', password 'Sterling@2026'
-- Note: Passwords are encrypted using crypt('...', gen_salt('bf'))
INSERT INTO shreeji_app.users (client_id, username, email, password_hash, role, full_name)
VALUES
    (NULL, 'admin', 'admin@shreejidiagnostics.com', crypt('Admin@Shreeji2026', gen_salt('bf')), 'ADMIN', 'Shreeji Central Admin'),
    (1, 'apex_pet', 'pet@apexhospital.org', crypt('Apex@2026', gen_salt('bf')), 'CLIENT', 'Apex Hospital PET Team'),
    (2, 'sterling_pet', 'orders@sterlingdiag.com', crypt('Sterling@2026', gen_salt('bf')), 'CLIENT', 'Sterling Imaging Coordinator'),
    (3, 'metro_pet', 'imaging@metrohospitals.in', crypt('Metro@2026', gen_salt('bf')), 'CLIENT', 'Metro Nuclear Medicine Desk')
ON CONFLICT (username) DO NOTHING;

-- Initial System Settings
INSERT INTO shreeji_app.app_settings (setting_key, setting_value, description)
VALUES
    ('company_profile', '{"name": "Shreeji Imaging and Diagnostics Center Private Limited", "portal": "Client Order Management Portal", "theme_primary": "#B51224", "theme_secondary": "#8F1020"}'::JSONB, 'Official branding details'),
    ('order_policies', '{"allow_cancellation_after_status": false, "max_lots_per_order": 20, "default_order_unit": "mCi"}'::JSONB, 'Order rules and constraints')
ON CONFLICT (setting_key) DO NOTHING;

-- ==============================================================================
-- 15. Reporting Views
-- ==============================================================================

-- Client-safe summary view
CREATE OR REPLACE VIEW shreeji_app.vw_client_order_summary AS
SELECT
    o.id AS internal_id,
    o.order_id,
    o.client_id,
    c.hospital_name,
    c.client_code,
    o.order_date,
    o.submission_timestamp,
    p.id AS product_id,
    p.name AS product_name,
    o.destination,
    o.status,
    o.total_lots,
    o.total_quantity,
    o.notes,
    o.created_at,
    o.updated_at,
    o.deleted_at
FROM shreeji_app.orders o
JOIN shreeji_app.clients c ON o.client_id = c.id
JOIN shreeji_app.products p ON o.product_id = p.id;
