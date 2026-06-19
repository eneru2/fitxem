-- +goose Up
CREATE TYPE schedule_template_type AS ENUM ('fixed', 'flexible');
CREATE TYPE employee_schedule_type AS ENUM ('none', 'template', 'custom', 'flexible');

CREATE TABLE schedule_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    schedule_type schedule_template_type NOT NULL,
    weekly_hours NUMERIC(5,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_schedule_templates_org ON schedule_templates(org_id);

CREATE TABLE schedule_template_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES schedule_templates(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CHECK (end_time > start_time)
);

CREATE INDEX idx_schedule_template_slots_template ON schedule_template_slots(template_id);

ALTER TABLE employees
    ADD COLUMN schedule_type employee_schedule_type NOT NULL DEFAULT 'none',
    ADD COLUMN schedule_template_id UUID REFERENCES schedule_templates(id) ON DELETE SET NULL,
    ADD COLUMN weekly_hours NUMERIC(5,2),
    ADD COLUMN vacation_days_annual INT NOT NULL DEFAULT 22;

CREATE TABLE employee_schedule_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CHECK (end_time > start_time)
);

CREATE INDEX idx_employee_schedule_slots_employee ON employee_schedule_slots(employee_id);

-- +goose Down
DROP TABLE IF EXISTS employee_schedule_slots;
ALTER TABLE employees
    DROP COLUMN IF EXISTS schedule_type,
    DROP COLUMN IF EXISTS schedule_template_id,
    DROP COLUMN IF EXISTS weekly_hours,
    DROP COLUMN IF EXISTS vacation_days_annual;
DROP TABLE IF EXISTS schedule_template_slots;
DROP TABLE IF EXISTS schedule_templates;
DROP TYPE IF EXISTS employee_schedule_type;
DROP TYPE IF EXISTS schedule_template_type;
