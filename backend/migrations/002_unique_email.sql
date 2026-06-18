-- +goose Up
CREATE UNIQUE INDEX idx_users_email_global ON users(email);

-- +goose Down
DROP INDEX IF EXISTS idx_users_email_global;
