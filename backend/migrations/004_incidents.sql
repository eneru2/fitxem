-- +goose Up
ALTER TABLE correction_requests
    ADD COLUMN incident_type VARCHAR(32) NOT NULL DEFAULT 'other',
    ADD COLUMN related_event_id UUID REFERENCES clock_events(id);

-- +goose Down
ALTER TABLE correction_requests
    DROP COLUMN IF EXISTS related_event_id,
    DROP COLUMN IF EXISTS incident_type;
