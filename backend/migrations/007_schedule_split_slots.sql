-- +goose Up
ALTER TABLE schedule_template_slots
    DROP CONSTRAINT IF EXISTS schedule_template_slots_template_id_day_of_week_key;

ALTER TABLE employee_schedule_slots
    DROP CONSTRAINT IF EXISTS employee_schedule_slots_employee_id_day_of_week_key;

-- +goose Down
-- Cannot restore one-slot-per-day without deleting duplicate rows.
