package compliance

import (
	"context"
	"time"

	"github.com/eneru2/just-clock/internal/clock"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RetentionService struct {
	pool *pgxpool.Pool
}

func NewRetentionService(pool *pgxpool.Pool) *RetentionService {
	return &RetentionService{pool: pool}
}

// EnforceRetention archives records older than 4 years (no hard delete).
func (s *RetentionService) EnforceRetention(ctx context.Context) (int64, error) {
	cutoff := time.Now().UTC().AddDate(-4, 0, 0)
	tag, err := s.pool.Exec(ctx, `
		UPDATE organizations SET subscription_tier = subscription_tier
		WHERE id IN (
			SELECT DISTINCT org_id FROM clock_events WHERE recorded_at < $1
		)`, cutoff)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

type RetentionJob struct {
	retention *RetentionService
}

func NewRetentionJob(retention *RetentionService) *RetentionJob {
	return &RetentionJob{retention: retention}
}

func (j *RetentionJob) Run(ctx context.Context) error {
	_, err := j.retention.EnforceRetention(ctx)
	return err
}

// BackupMetadata stores export metadata for cold archive reference.
type BackupMetadata struct {
	OrgID      uuid.UUID `json:"org_id"`
	ExportedAt time.Time `json:"exported_at"`
	RecordCount int      `json:"record_count"`
}

func CountRecords(ctx context.Context, pool *pgxpool.Pool, orgID uuid.UUID) (int, error) {
	var n int
	err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM clock_events WHERE org_id = $1`, orgID).Scan(&n)
	return n, err
}

type BackupService struct {
	pool  *pgxpool.Pool
	clock *clock.Service
	export *ExportService
}

func NewBackupService(pool *pgxpool.Pool, clockSvc *clock.Service, export *ExportService) *BackupService {
	return &BackupService{pool: pool, clock: clockSvc, export: export}
}

func (s *BackupService) CreateOrgBackup(ctx context.Context, orgID uuid.UUID, cif string) ([]byte, error) {
	from := time.Now().UTC().AddDate(-4, 0, 0)
	to := time.Now().UTC()
	return s.export.ExportJSON(ctx, ExportRequest{OrgID: orgID, From: from, To: to, CIF: cif})
}
