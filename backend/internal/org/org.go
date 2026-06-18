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
	ID           uuid.UUID  `json:"id"`
	OrgID        uuid.UUID  `json:"org_id"`
	NIF          string     `json:"nif"`
	FullName     string     `json:"full_name"`
	Email        string     `json:"email,omitempty"`
	Role         string     `json:"role"`
	WorkCenterID *uuid.UUID `json:"work_center_id,omitempty"`
	Active       bool       `json:"active"`
}

type WorkCenter struct {
	ID       uuid.UUID `json:"id"`
	OrgID    uuid.UUID `json:"org_id"`
	Name     string    `json:"name"`
	Address  string    `json:"address,omitempty"`
	Timezone string    `json:"timezone"`
}

type CreateEmployeeInput struct {
	OrgID        uuid.UUID
	NIF          string
	FullName     string
	Email        string
	Password     string
	Role         string
	WorkCenterID *uuid.UUID
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
			e.work_center_id, e.active
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
		if err := rows.Scan(&e.ID, &e.OrgID, &e.NIF, &e.FullName, &e.Email, &e.Role, &e.WorkCenterID, &e.Active); err != nil {
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
		INSERT INTO employees (org_id, user_id, work_center_id, nif, full_name)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, org_id, nif, full_name, work_center_id, active`,
		in.OrgID, userID, in.WorkCenterID, in.NIF, in.FullName,
	).Scan(&e.ID, &e.OrgID, &e.NIF, &e.FullName, &e.WorkCenterID, &e.Active)
	if err != nil {
		return nil, err
	}
	e.Email = in.Email
	e.Role = in.Role

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &e, nil
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
