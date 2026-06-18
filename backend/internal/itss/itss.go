package itss

import (
	"context"
	"errors"
	"time"

	"github.com/eneru2/just-clock/internal/clock"
	"github.com/eneru2/just-clock/internal/compliance"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrCompanyNotFound = errors.New("company not found")

type Service struct {
	pool  *pgxpool.Pool
	clock *clock.Service
	audit *compliance.AuditService
}

func NewService(pool *pgxpool.Pool, clockSvc *clock.Service, audit *compliance.AuditService) *Service {
	return &Service{pool: pool, clock: clockSvc, audit: audit}
}

type RecordsResponse struct {
	CompanyCIF string         `json:"company_cif"`
	From       time.Time      `json:"from"`
	To         time.Time      `json:"to"`
	Records    []ITSSRecord   `json:"records"`
}

type ITSSRecord struct {
	EmployeeNIF  string    `json:"employee_nif"`
	EmployeeName string    `json:"employee_name"`
	EventType    string    `json:"event_type"`
	RecordedAt   time.Time `json:"recorded_at"`
	HourType     string    `json:"hour_type"`
	WorkCenter   string    `json:"work_center,omitempty"`
	EventHash    string    `json:"event_hash"`
	IsCorrection bool      `json:"is_correction"`
}

func (s *Service) GetCompanyRecords(ctx context.Context, cif string, from, to time.Time, ip string) (*RecordsResponse, error) {
	orgID, err := s.orgIDByCIF(ctx, cif)
	if err != nil {
		return nil, err
	}
	_ = s.logAccess(ctx, orgID, "/records", ip)

	records, err := s.clock.ListOrgRecords(ctx, orgID, from, to)
	if err != nil {
		return nil, err
	}
	resp := &RecordsResponse{CompanyCIF: cif, From: from, To: to}
	for _, r := range records {
		resp.Records = append(resp.Records, ITSSRecord{
			EmployeeNIF:  r.EmployeeNIF,
			EmployeeName: r.EmployeeName,
			EventType:    string(r.EventType),
			RecordedAt:   r.RecordedAt,
			HourType:     r.HourType,
			WorkCenter:   r.WorkCenterName,
			EventHash:    r.EventHash,
			IsCorrection: r.IsCorrection,
		})
	}
	return resp, nil
}

func (s *Service) GetEmployeeRecords(ctx context.Context, cif, nif string, from, to time.Time, ip string) (*RecordsResponse, error) {
	orgID, err := s.orgIDByCIF(ctx, cif)
	if err != nil {
		return nil, err
	}
	employeeID, err := s.employeeIDByNIF(ctx, orgID, nif)
	if err != nil {
		return nil, err
	}
	_ = s.logAccess(ctx, orgID, "/employees/"+nif+"/records", ip)

	records, err := s.clock.ListRecords(ctx, orgID, employeeID, from, to)
	if err != nil {
		return nil, err
	}
	resp := &RecordsResponse{CompanyCIF: cif, From: from, To: to}
	var empName, empNIF string
	_ = s.pool.QueryRow(ctx, `SELECT nif, full_name FROM employees WHERE id = $1`, employeeID).Scan(&empNIF, &empName)
	for _, r := range records {
		resp.Records = append(resp.Records, ITSSRecord{
			EmployeeNIF:  empNIF,
			EmployeeName: empName,
			EventType:    string(r.EventType),
			RecordedAt:   r.RecordedAt,
			HourType:     r.HourType,
			EventHash:    r.EventHash,
			IsCorrection: r.IsCorrection,
		})
	}
	return resp, nil
}

func (s *Service) GetAuditLog(ctx context.Context, cif string, from, to time.Time, limit int, ip string) ([]compliance.AuditEntry, error) {
	orgID, err := s.orgIDByCIF(ctx, cif)
	if err != nil {
		return nil, err
	}
	_ = s.logAccess(ctx, orgID, "/audit-log", ip)
	return s.audit.List(ctx, orgID, from.Format(time.RFC3339), to.Format(time.RFC3339), limit)
}

func (s *Service) orgIDByCIF(ctx context.Context, cif string) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx, `SELECT id FROM organizations WHERE cif = $1`, cif).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, ErrCompanyNotFound
		}
		return uuid.Nil, err
	}
	return id, nil
}

func (s *Service) employeeIDByNIF(ctx context.Context, orgID uuid.UUID, nif string) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx, `SELECT id FROM employees WHERE org_id = $1 AND nif = $2`, orgID, nif).Scan(&id)
	if err != nil {
		return uuid.Nil, err
	}
	return id, nil
}

func (s *Service) logAccess(ctx context.Context, orgID uuid.UUID, endpoint, ip string) error {
	_, err := s.pool.Exec(ctx,
		`INSERT INTO itss_access_log (org_id, endpoint, ip_address) VALUES ($1, $2, $3::inet)`,
		orgID, endpoint, ip,
	)
	return err
}
