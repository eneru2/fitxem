package absence

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound    = errors.New("absence not found")
	ErrInvalidType = errors.New("invalid absence type")
	ErrDateRange   = errors.New("end_date must be on or after start_date")
	ErrOverlap     = errors.New("overlaps with an approved absence")
)

type AbsenceType string

const (
	TypeVacation AbsenceType = "vacation"
	TypeSick     AbsenceType = "sick"
	TypePersonal AbsenceType = "personal"
	TypeUnpaid   AbsenceType = "unpaid"
)

type Service struct {
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

type Request struct {
	ID           uuid.UUID `json:"id"`
	OrgID        uuid.UUID `json:"org_id"`
	EmployeeID   uuid.UUID `json:"employee_id"`
	EmployeeName string    `json:"employee_name,omitempty"`
	AbsenceType  string    `json:"absence_type"`
	StartDate    time.Time `json:"start_date"`
	EndDate      time.Time `json:"end_date"`
	Reason       string    `json:"reason"`
	Status       string    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
}

type CreateInput struct {
	OrgID       uuid.UUID
	EmployeeID  uuid.UUID
	RequestedBy uuid.UUID
	AbsenceType AbsenceType
	StartDate   time.Time
	EndDate     time.Time
	Reason      string
}

const requestSelect = `
	SELECT ar.id, ar.org_id, ar.employee_id, e.full_name,
		ar.absence_type::text, ar.start_date, ar.end_date, ar.reason,
		ar.status::text, ar.created_at
	FROM absence_requests ar
	JOIN employees e ON e.id = ar.employee_id`

func validAbsenceType(t AbsenceType) bool {
	switch t {
	case TypeVacation, TypeSick, TypePersonal, TypeUnpaid:
		return true
	default:
		return false
	}
}

func dateOnly(t time.Time) time.Time {
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func (s *Service) checkOverlap(ctx context.Context, orgID, employeeID uuid.UUID, start, end time.Time, excludeID *uuid.UUID) error {
	start = dateOnly(start)
	end = dateOnly(end)
	q := `
		SELECT 1 FROM absence_requests
		WHERE org_id = $1 AND employee_id = $2 AND status = 'approved'
		  AND start_date <= $4 AND end_date >= $3`
	args := []any{orgID, employeeID, start, end}
	if excludeID != nil {
		q += ` AND id != $5`
		args = append(args, *excludeID)
	}
	var one int
	err := s.pool.QueryRow(ctx, q, args...).Scan(&one)
	if err == nil {
		return ErrOverlap
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	return err
}

func (s *Service) Create(ctx context.Context, in CreateInput) (*Request, error) {
	if !validAbsenceType(in.AbsenceType) {
		return nil, ErrInvalidType
	}
	start := dateOnly(in.StartDate)
	end := dateOnly(in.EndDate)
	if end.Before(start) {
		return nil, ErrDateRange
	}
	if err := s.checkOverlap(ctx, in.OrgID, in.EmployeeID, start, end, nil); err != nil {
		return nil, err
	}

	var id uuid.UUID
	err := s.pool.QueryRow(ctx, `
		INSERT INTO absence_requests (
			org_id, employee_id, requested_by, absence_type, start_date, end_date, reason
		) VALUES ($1,$2,$3,$4::absence_type,$5,$6,$7)
		RETURNING id`,
		in.OrgID, in.EmployeeID, in.RequestedBy, string(in.AbsenceType), start, end, in.Reason,
	).Scan(&id)
	if err != nil {
		return nil, err
	}
	return s.GetByID(ctx, in.OrgID, id)
}

func (s *Service) GetByID(ctx context.Context, orgID, id uuid.UUID) (*Request, error) {
	req, err := scanRequest(s.pool.QueryRow(ctx, requestSelect+` WHERE ar.id = $1 AND ar.org_id = $2`, id, orgID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &req, nil
}

func (s *Service) Review(ctx context.Context, orgID, absenceID, reviewerID uuid.UUID, approve bool) (*Request, error) {
	status := "rejected"
	if approve {
		status = "approved"
	}

	var start, end time.Time
	var employeeID uuid.UUID
	err := s.pool.QueryRow(ctx, `
		SELECT employee_id, start_date, end_date FROM absence_requests
		WHERE id = $1 AND org_id = $2 AND status = 'pending'`,
		absenceID, orgID,
	).Scan(&employeeID, &start, &end)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	if approve {
		if err := s.checkOverlap(ctx, orgID, employeeID, start, end, &absenceID); err != nil {
			return nil, err
		}
	}

	_, err = s.pool.Exec(ctx, `
		UPDATE absence_requests
		SET status = $1::correction_status, reviewed_by = $2, reviewed_at = NOW()
		WHERE id = $3 AND org_id = $4 AND status = 'pending'`,
		status, reviewerID, absenceID, orgID,
	)
	if err != nil {
		return nil, err
	}
	return s.GetByID(ctx, orgID, absenceID)
}

func (s *Service) ListPending(ctx context.Context, orgID uuid.UUID) ([]Request, error) {
	rows, err := s.pool.Query(ctx, requestSelect+`
		WHERE ar.org_id = $1 AND ar.status = 'pending'
		ORDER BY ar.created_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanRequests(rows)
}

func (s *Service) ListMine(ctx context.Context, orgID, employeeID uuid.UUID) ([]Request, error) {
	rows, err := s.pool.Query(ctx, requestSelect+`
		WHERE ar.org_id = $1 AND ar.employee_id = $2
		ORDER BY ar.created_at DESC`, orgID, employeeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanRequests(rows)
}

func (s *Service) ListApprovedInRange(ctx context.Context, orgID, employeeID uuid.UUID, from, to time.Time) ([]Request, error) {
	from = dateOnly(from)
	to = dateOnly(to)
	rows, err := s.pool.Query(ctx, requestSelect+`
		WHERE ar.org_id = $1 AND ar.employee_id = $2 AND ar.status = 'approved'
		  AND ar.end_date >= $3 AND ar.start_date <= $4
		ORDER BY ar.start_date ASC`, orgID, employeeID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanRequests(rows)
}

func scanRequest(row pgx.Row) (Request, error) {
	var req Request
	err := row.Scan(
		&req.ID, &req.OrgID, &req.EmployeeID, &req.EmployeeName,
		&req.AbsenceType, &req.StartDate, &req.EndDate, &req.Reason,
		&req.Status, &req.CreatedAt,
	)
	return req, err
}

func scanRequests(rows pgx.Rows) ([]Request, error) {
	var out []Request
	for rows.Next() {
		req, err := scanRequest(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, req)
	}
	return out, rows.Err()
}
