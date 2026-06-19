package org

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

var ErrNotFound = errors.New("not found")

type Service struct {
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

type Organization struct {
	ID              uuid.UUID `json:"id"`
	CIF             string    `json:"cif"`
	LegalName       string    `json:"legal_name"`
	SubscriptionTier string   `json:"subscription_tier"`
}

type Employee struct {
	ID                 uuid.UUID  `json:"id"`
	OrgID              uuid.UUID  `json:"org_id"`
	NIF                string     `json:"nif"`
	FullName           string     `json:"full_name"`
	Email              string     `json:"email,omitempty"`
	Role               string     `json:"role"`
	WorkCenterID       *uuid.UUID `json:"work_center_id,omitempty"`
	Active             bool       `json:"active"`
	ScheduleType       string     `json:"schedule_type"`
	ScheduleTemplateID *uuid.UUID `json:"schedule_template_id,omitempty"`
	WeeklyHours        *float64   `json:"weekly_hours,omitempty"`
	VacationDaysAnnual int        `json:"vacation_days_annual"`
}

type WorkCenter struct {
	ID       uuid.UUID `json:"id"`
	OrgID    uuid.UUID `json:"org_id"`
	Name     string    `json:"name"`
	Address  string    `json:"address,omitempty"`
	Timezone string    `json:"timezone"`
}

type CreateEmployeeInput struct {
	OrgID              uuid.UUID
	NIF                string
	FullName           string
	Email              string
	Password           string
	Role               string
	WorkCenterID       *uuid.UUID
	VacationDaysAnnual int
	ScheduleType       string
	ScheduleTemplateID *uuid.UUID
	WeeklyHours        *float64
	ScheduleSlots      []ScheduleSlotInput
}

type ScheduleSlotInput struct {
	DayOfWeek int
	StartTime string
	EndTime   string
}

type UpdateEmployeeInput struct {
	OrgID              uuid.UUID
	EmployeeID         uuid.UUID
	VacationDaysAnnual *int
}

func (s *Service) GetOrg(ctx context.Context, orgID uuid.UUID) (*Organization, error) {
	var o Organization
	err := s.pool.QueryRow(ctx,
		`SELECT id, cif, legal_name, subscription_tier FROM organizations WHERE id = $1`,
		orgID,
	).Scan(&o.ID, &o.CIF, &o.LegalName, &o.SubscriptionTier)
	if err != nil {
		return nil, err
	}
	return &o, nil
}

func (s *Service) ListEmployees(ctx context.Context, orgID uuid.UUID) ([]Employee, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT e.id, e.org_id, e.nif, e.full_name, COALESCE(u.email, ''), COALESCE(u.role::text, 'employee'),
			e.work_center_id, e.active, e.schedule_type::text, e.schedule_template_id, e.weekly_hours,
			e.vacation_days_annual
		FROM employees e
		LEFT JOIN users u ON u.id = e.user_id
		WHERE e.org_id = $1 ORDER BY e.full_name`,
		orgID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Employee
	for rows.Next() {
		var e Employee
		if err := rows.Scan(
			&e.ID, &e.OrgID, &e.NIF, &e.FullName, &e.Email, &e.Role, &e.WorkCenterID, &e.Active,
			&e.ScheduleType, &e.ScheduleTemplateID, &e.WeeklyHours, &e.VacationDaysAnnual,
		); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Service) CreateEmployee(ctx context.Context, in CreateEmployeeInput) (*Employee, error) {
	if in.Role == "" {
		in.Role = "employee"
	}
	if in.VacationDaysAnnual <= 0 {
		in.VacationDaysAnnual = 22
	}
	if in.ScheduleType == "" {
		in.ScheduleType = "none"
	}
	switch in.ScheduleType {
	case "template":
		if in.ScheduleTemplateID == nil {
			return nil, errors.New("schedule_template_id required for template schedule")
		}
	case "flexible":
		if in.WeeklyHours == nil || *in.WeeklyHours <= 0 {
			return nil, errors.New("weekly_hours required for flexible schedule")
		}
	case "custom":
		if len(in.ScheduleSlots) == 0 {
			return nil, errors.New("schedule_slots required for custom schedule")
		}
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var userID *uuid.UUID
	if in.Email != "" && in.Password != "" {
		hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
		if err != nil {
			return nil, err
		}
		var uid uuid.UUID
		err = tx.QueryRow(ctx,
			`INSERT INTO users (org_id, email, password_hash, role) VALUES ($1,$2,$3,$4::user_role) RETURNING id`,
			in.OrgID, in.Email, string(hash), in.Role,
		).Scan(&uid)
		if err != nil {
			return nil, err
		}
		userID = &uid
	}

	var e Employee
	err = tx.QueryRow(ctx, `
		INSERT INTO employees (
			org_id, user_id, work_center_id, nif, full_name,
			vacation_days_annual, schedule_type, schedule_template_id, weekly_hours
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7::employee_schedule_type,$8,$9)
		RETURNING id, org_id, nif, full_name, work_center_id, active,
			schedule_type::text, schedule_template_id, weekly_hours, vacation_days_annual`,
		in.OrgID, userID, in.WorkCenterID, in.NIF, in.FullName,
		in.VacationDaysAnnual, in.ScheduleType, in.ScheduleTemplateID, in.WeeklyHours,
	).Scan(
		&e.ID, &e.OrgID, &e.NIF, &e.FullName, &e.WorkCenterID, &e.Active,
		&e.ScheduleType, &e.ScheduleTemplateID, &e.WeeklyHours, &e.VacationDaysAnnual,
	)
	if err != nil {
		return nil, err
	}
	e.Email = in.Email
	e.Role = in.Role

	if in.ScheduleType == "custom" && len(in.ScheduleSlots) > 0 {
		for _, sl := range in.ScheduleSlots {
			_, err = tx.Exec(ctx, `
				INSERT INTO employee_schedule_slots (employee_id, day_of_week, start_time, end_time)
				VALUES ($1, $2, $3::time, $4::time)`,
				e.ID, sl.DayOfWeek, sl.StartTime, sl.EndTime,
			)
			if err != nil {
				return nil, err
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &e, nil
}

func (s *Service) UpdateEmployee(ctx context.Context, in UpdateEmployeeInput) (*Employee, error) {
	if in.VacationDaysAnnual == nil {
		return nil, errors.New("nothing to update")
	}
	var e Employee
	err := s.pool.QueryRow(ctx, `
		UPDATE employees SET vacation_days_annual = $1
		WHERE id = $2 AND org_id = $3
		RETURNING id, org_id, nif, full_name, work_center_id, active,
			schedule_type::text, schedule_template_id, weekly_hours, vacation_days_annual`,
		*in.VacationDaysAnnual, in.EmployeeID, in.OrgID,
	).Scan(
		&e.ID, &e.OrgID, &e.NIF, &e.FullName, &e.WorkCenterID, &e.Active,
		&e.ScheduleType, &e.ScheduleTemplateID, &e.WeeklyHours, &e.VacationDaysAnnual,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &e, nil
}

func (s *Service) GetVacationDaysAnnual(ctx context.Context, employeeID uuid.UUID) (int, error) {
	var days int
	err := s.pool.QueryRow(ctx,
		`SELECT vacation_days_annual FROM employees WHERE id = $1`, employeeID,
	).Scan(&days)
	return days, err
}

func (s *Service) ListWorkCenters(ctx context.Context, orgID uuid.UUID) ([]WorkCenter, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT id, org_id, name, COALESCE(address,''), timezone FROM work_centers WHERE org_id = $1`,
		orgID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []WorkCenter
	for rows.Next() {
		var wc WorkCenter
		if err := rows.Scan(&wc.ID, &wc.OrgID, &wc.Name, &wc.Address, &wc.Timezone); err != nil {
			return nil, err
		}
		out = append(out, wc)
	}
	return out, rows.Err()
}

func (s *Service) CreateWorkCenter(ctx context.Context, orgID uuid.UUID, name, address, timezone string) (*WorkCenter, error) {
	if timezone == "" {
		timezone = "Europe/Madrid"
	}
	var wc WorkCenter
	err := s.pool.QueryRow(ctx, `
		INSERT INTO work_centers (org_id, name, address, timezone) VALUES ($1,$2,$3,$4)
		RETURNING id, org_id, name, COALESCE(address,''), timezone`,
		orgID, name, address, timezone,
	).Scan(&wc.ID, &wc.OrgID, &wc.Name, &wc.Address, &wc.Timezone)
	return &wc, err
}

func (s *Service) UpdateSubscription(ctx context.Context, orgID uuid.UUID, tier, stripeCustomerID string) error {
	_, err := s.pool.Exec(ctx,
		`UPDATE organizations SET subscription_tier = $1, stripe_customer_id = $2 WHERE id = $3`,
		tier, stripeCustomerID, orgID,
	)
	return err
}

func (s *Service) GetByStripeCustomer(ctx context.Context, customerID string) (*Organization, error) {
	var o Organization
	err := s.pool.QueryRow(ctx,
		`SELECT id, cif, legal_name, subscription_tier FROM organizations WHERE stripe_customer_id = $1`,
		customerID,
	).Scan(&o.ID, &o.CIF, &o.LegalName, &o.SubscriptionTier)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return &o, err
}
