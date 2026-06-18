package correction

import (
	"context"
	"errors"
	"time"

	"github.com/eneru2/just-clock/internal/clock"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound          = errors.New("correction not found")
	ErrInvalidIncident   = errors.New("invalid incident type")
	ErrRelatedEvent      = errors.New("related event not found or not owned by employee")
	ErrWrongTimeRequired = errors.New("wrong_time requires related_event_id")
	ErrForgotClockEvent  = errors.New("forgot_clock must not set related_event_id")
)

type IncidentType string

const (
	IncidentForgotClock IncidentType = "forgot_clock"
	IncidentWrongTime   IncidentType = "wrong_time"
	IncidentOther       IncidentType = "other"
)

type Service struct {
	pool  *pgxpool.Pool
	clock *clock.Service
}

func NewService(pool *pgxpool.Pool, clockSvc *clock.Service) *Service {
	return &Service{pool: pool, clock: clockSvc}
}

type Request struct {
	ID                 uuid.UUID  `json:"id"`
	OrgID              uuid.UUID  `json:"org_id"`
	EmployeeID         uuid.UUID  `json:"employee_id"`
	EmployeeName       string     `json:"employee_name,omitempty"`
	EventType          string     `json:"event_type"`
	ProposedAt         time.Time  `json:"proposed_at"`
	Reason             string     `json:"reason"`
	IncidentType       string     `json:"incident_type"`
	RelatedEventID     *uuid.UUID `json:"related_event_id,omitempty"`
	OriginalRecordedAt *time.Time `json:"original_recorded_at,omitempty"`
	Status             string     `json:"status"`
	CreatedAt          time.Time  `json:"created_at"`
}

type CreateInput struct {
	OrgID          uuid.UUID
	EmployeeID     uuid.UUID
	RequestedBy    uuid.UUID
	EventType      clock.EventType
	ProposedAt     time.Time
	Reason         string
	IncidentType   IncidentType
	RelatedEventID *uuid.UUID
}

const requestSelect = `
	SELECT cr.id, cr.org_id, cr.employee_id, e.full_name,
		cr.event_type::text, cr.proposed_at, cr.reason,
		cr.incident_type, cr.related_event_id, ce.recorded_at,
		cr.status::text, cr.created_at
	FROM correction_requests cr
	JOIN employees e ON e.id = cr.employee_id
	LEFT JOIN clock_events ce ON ce.id = cr.related_event_id`

func scanRequest(row pgx.Row) (Request, error) {
	var cr Request
	var originalRecordedAt *time.Time
	err := row.Scan(
		&cr.ID, &cr.OrgID, &cr.EmployeeID, &cr.EmployeeName,
		&cr.EventType, &cr.ProposedAt, &cr.Reason,
		&cr.IncidentType, &cr.RelatedEventID, &originalRecordedAt,
		&cr.Status, &cr.CreatedAt,
	)
	if err != nil {
		return Request{}, err
	}
	cr.OriginalRecordedAt = originalRecordedAt
	return cr, nil
}

func validateCreateInput(ctx context.Context, pool *pgxpool.Pool, in CreateInput) error {
	switch in.IncidentType {
	case IncidentForgotClock, IncidentWrongTime, IncidentOther:
	default:
		if in.IncidentType == "" {
			in.IncidentType = IncidentOther
		} else {
			return ErrInvalidIncident
		}
	}
	if in.IncidentType == IncidentWrongTime {
		if in.RelatedEventID == nil {
			return ErrWrongTimeRequired
		}
		var owner uuid.UUID
		err := pool.QueryRow(ctx, `
			SELECT employee_id FROM clock_events
			WHERE id = $1 AND org_id = $2`, *in.RelatedEventID, in.OrgID,
		).Scan(&owner)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrRelatedEvent
			}
			return err
		}
		if owner != in.EmployeeID {
			return ErrRelatedEvent
		}
	}
	if in.IncidentType == IncidentForgotClock && in.RelatedEventID != nil {
		return ErrForgotClockEvent
	}
	return nil
}

func (s *Service) Create(ctx context.Context, in CreateInput) (*Request, error) {
	if in.IncidentType == "" {
		in.IncidentType = IncidentOther
	}
	if err := validateCreateInput(ctx, s.pool, in); err != nil {
		return nil, err
	}
	row := s.pool.QueryRow(ctx, `
		INSERT INTO correction_requests (
			org_id, employee_id, requested_by, event_type, proposed_at, reason,
			incident_type, related_event_id
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id`,
		in.OrgID, in.EmployeeID, in.RequestedBy, in.EventType, in.ProposedAt, in.Reason,
		string(in.IncidentType), in.RelatedEventID,
	)
	var id uuid.UUID
	if err := row.Scan(&id); err != nil {
		return nil, err
	}
	return s.GetByID(ctx, in.OrgID, id)
}

func (s *Service) GetByID(ctx context.Context, orgID, id uuid.UUID) (*Request, error) {
	cr, err := scanRequest(s.pool.QueryRow(ctx, requestSelect+` WHERE cr.id = $1 AND cr.org_id = $2`, id, orgID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &cr, nil
}

func (s *Service) Review(ctx context.Context, orgID, correctionID, reviewerID uuid.UUID, approve bool) (*Request, error) {
	status := "rejected"
	if approve {
		status = "approved"
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var cr Request
	err = tx.QueryRow(ctx, `
		UPDATE correction_requests
		SET status = $1::correction_status, reviewed_by = $2, reviewed_at = NOW()
		WHERE id = $3 AND org_id = $4 AND status = 'pending'
		RETURNING id, org_id, employee_id, event_type::text, proposed_at, reason, incident_type, related_event_id, status::text, created_at`,
		status, reviewerID, correctionID, orgID,
	).Scan(&cr.ID, &cr.OrgID, &cr.EmployeeID, &cr.EventType, &cr.ProposedAt, &cr.Reason,
		&cr.IncidentType, &cr.RelatedEventID, &cr.Status, &cr.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	if approve {
		corrID := cr.ID
		_, err = s.clock.Record(ctx, clock.RecordInput{
			OrgID:               orgID,
			EmployeeID:          cr.EmployeeID,
			EventType:           clock.EventType(cr.EventType),
			ClientAt:            &cr.ProposedAt,
			IsCorrection:        true,
			CorrectionRequestID: &corrID,
		})
		if err != nil {
			return nil, err
		}
	}
	return s.GetByID(ctx, orgID, cr.ID)
}

func (s *Service) ListPending(ctx context.Context, orgID uuid.UUID) ([]Request, error) {
	rows, err := s.pool.Query(ctx, requestSelect+`
		WHERE cr.org_id = $1 AND cr.status = 'pending'
		ORDER BY cr.created_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanRequests(rows)
}

func (s *Service) ListMine(ctx context.Context, orgID, employeeID uuid.UUID) ([]Request, error) {
	rows, err := s.pool.Query(ctx, requestSelect+`
		WHERE cr.org_id = $1 AND cr.employee_id = $2
		ORDER BY cr.created_at DESC`, orgID, employeeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanRequests(rows)
}

func scanRequests(rows pgx.Rows) ([]Request, error) {
	var out []Request
	for rows.Next() {
		var cr Request
		var originalRecordedAt *time.Time
		if err := rows.Scan(
			&cr.ID, &cr.OrgID, &cr.EmployeeID, &cr.EmployeeName,
			&cr.EventType, &cr.ProposedAt, &cr.Reason,
			&cr.IncidentType, &cr.RelatedEventID, &originalRecordedAt,
			&cr.Status, &cr.CreatedAt,
		); err != nil {
			return nil, err
		}
		cr.OriginalRecordedAt = originalRecordedAt
		out = append(out, cr)
	}
	return out, rows.Err()
}
