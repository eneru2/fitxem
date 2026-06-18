-- +goose Up
ALTER TABLE clock_events
    ADD COLUMN latitude DOUBLE PRECISION,
    ADD COLUMN longitude DOUBLE PRECISION;

ALTER TABLE work_centers
    ADD COLUMN latitude DOUBLE PRECISION,
    ADD COLUMN longitude DOUBLE PRECISION;

-- +goose Down
ALTER TABLE clock_events
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS longitude;

ALTER TABLE work_centers
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS longitude;
