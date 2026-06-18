-- +goose Up
CREATE TYPE absence_type AS ENUM ('vacation', 'sick', 'personal', 'unpaid');

CREATE TABLE absence_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    requested_by UUID NOT NULL REFERENCES users(id),
    absence_type absence_type NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status correction_status NOT NULL DEFAULT 'pending',
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (end_date >= start_date)
);

CREATE INDEX idx_absence_requests_org_employee ON absence_requests(org_id, employee_id, start_date DESC);
CREATE INDEX idx_absence_requests_org_pending ON absence_requests(org_id) WHERE status = 'pending';

-- +goose Down
DROP TABLE IF EXISTS absence_requests;
DROP TYPE IF EXISTS absence_type;
