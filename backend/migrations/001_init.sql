-- +goose Up
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cif VARCHAR(20) NOT NULL UNIQUE,
    legal_name VARCHAR(255) NOT NULL,
    subscription_tier VARCHAR(50) NOT NULL DEFAULT 'trial',
    stripe_customer_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE work_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    timezone VARCHAR(64) NOT NULL DEFAULT 'Europe/Madrid',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TYPE user_role AS ENUM ('owner', 'admin', 'employee');

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'employee',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, email)
);

CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    user_id UUID REFERENCES users(id),
    work_center_id UUID REFERENCES work_centers(id),
    nif VARCHAR(20) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, nif)
);

CREATE TYPE clock_event_type AS ENUM ('in', 'out', 'break_start', 'break_end');
CREATE TYPE hour_type AS ENUM ('ordinary', 'extra', 'complementary');

CREATE TABLE clock_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    event_type clock_event_type NOT NULL,
    hour_type hour_type NOT NULL DEFAULT 'ordinary',
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    client_at TIMESTAMPTZ,
    work_center_id UUID REFERENCES work_centers(id),
    prev_hash VARCHAR(64) NOT NULL DEFAULT '',
    event_hash VARCHAR(64) NOT NULL,
    tsa_token BYTEA,
    is_correction BOOLEAN NOT NULL DEFAULT FALSE,
    correction_request_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clock_events_org_employee ON clock_events(org_id, employee_id, recorded_at DESC);
CREATE INDEX idx_clock_events_org_recorded ON clock_events(org_id, recorded_at DESC);

CREATE TYPE correction_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE correction_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    requested_by UUID NOT NULL REFERENCES users(id),
    event_type clock_event_type NOT NULL,
    proposed_at TIMESTAMPTZ NOT NULL,
    reason TEXT NOT NULL,
    status correction_status NOT NULL DEFAULT 'pending',
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    ip_address INET,
    payload_hash VARCHAR(64),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_org ON audit_log(org_id, created_at DESC);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE itss_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    endpoint VARCHAR(255) NOT NULL,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- +goose Down
DROP TABLE IF EXISTS itss_access_log;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS correction_requests;
DROP TABLE IF EXISTS clock_events;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS work_centers;
DROP TABLE IF EXISTS organizations;
DROP TYPE IF EXISTS correction_status;
DROP TYPE IF EXISTS hour_type;
DROP TYPE IF EXISTS clock_event_type;
DROP TYPE IF EXISTS user_role;
