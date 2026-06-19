package dashboard

import (
	"context"
	"fmt"

	"github.com/eneru2/just-clock/dashboard/dashdata"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	pool *pgxpool.Pool
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) GetStats(ctx context.Context) (*dashdata.Stats, error) {
	var st dashdata.Stats
	err := s.pool.QueryRow(ctx, `
		SELECT
			(SELECT COUNT(*) FROM organizations),
			(SELECT COUNT(*) FROM users),
			(SELECT COUNT(*) FROM employees),
			(SELECT COUNT(*) FROM employees WHERE active),
			(SELECT COUNT(*) FROM clock_events WHERE recorded_at >= CURRENT_DATE),
			(SELECT COUNT(*) FROM clock_events),
			(SELECT COUNT(*) FROM correction_requests WHERE status = 'pending'),
			(SELECT COUNT(*) FROM absence_requests WHERE status = 'pending')
	`).Scan(&st.OrgCount, &st.UserCount, &st.EmployeeCount, &st.ActiveEmployees,
		&st.ClockEventsToday, &st.ClockEventsTotal, &st.PendingCorrections, &st.PendingAbsences)
	if err != nil {
		return nil, err
	}
	return &st, nil
}

func (s *Store) ListOrganizations(ctx context.Context, search string, limit int) ([]dashdata.Organization, error) {
	if limit <= 0 {
		limit = 100
	}
	q := `
		SELECT o.id, o.cif, o.legal_name, o.subscription_tier, o.stripe_customer_id, o.created_at,
			(SELECT COUNT(*) FROM employees e WHERE e.org_id = o.id),
			(SELECT COUNT(*) FROM users u WHERE u.org_id = o.id),
			(SELECT COUNT(*) FROM clock_events c WHERE c.org_id = o.id)
		FROM organizations o
	`
	args := []any{}
	if search != "" {
		q += ` WHERE o.cif ILIKE $1 OR o.legal_name ILIKE $1`
		args = append(args, "%"+search+"%")
	}
	q += ` ORDER BY o.created_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.Organization
	for rows.Next() {
		var o dashdata.Organization
		if err := rows.Scan(&o.ID, &o.CIF, &o.LegalName, &o.SubscriptionTier, &o.StripeCustomerID,
			&o.CreatedAt, &o.EmployeeCount, &o.UserCount, &o.ClockEventCount); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

func (s *Store) GetOrganization(ctx context.Context, id uuid.UUID) (*dashdata.Organization, error) {
	var o dashdata.Organization
	err := s.pool.QueryRow(ctx, `
		SELECT o.id, o.cif, o.legal_name, o.subscription_tier, o.stripe_customer_id, o.created_at,
			(SELECT COUNT(*) FROM employees e WHERE e.org_id = o.id),
			(SELECT COUNT(*) FROM users u WHERE u.org_id = o.id),
			(SELECT COUNT(*) FROM clock_events c WHERE c.org_id = o.id)
		FROM organizations o WHERE o.id = $1`, id,
	).Scan(&o.ID, &o.CIF, &o.LegalName, &o.SubscriptionTier, &o.StripeCustomerID,
		&o.CreatedAt, &o.EmployeeCount, &o.UserCount, &o.ClockEventCount)
	if err != nil {
		return nil, err
	}
	return &o, nil
}

func (s *Store) ListEmployees(ctx context.Context, orgID *uuid.UUID, search string, limit int) ([]dashdata.Employee, error) {
	if limit <= 0 {
		limit = 200
	}
	q := `
		SELECT e.id, e.org_id, e.user_id, e.nif, e.full_name, u.email, u.role::text,
			e.active, e.schedule_type::text, e.vacation_days_annual, e.created_at
		FROM employees e
		LEFT JOIN users u ON u.id = e.user_id
		WHERE 1=1
	`
	args := []any{}
	n := 1
	if orgID != nil {
		q += fmt.Sprintf(` AND e.org_id = $%d`, n)
		args = append(args, *orgID)
		n++
	}
	if search != "" {
		q += fmt.Sprintf(` AND (e.nif ILIKE $%d OR e.full_name ILIKE $%d OR u.email ILIKE $%d)`, n, n, n)
		args = append(args, "%"+search+"%")
		n++
	}
	q += ` ORDER BY e.created_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.Employee
	for rows.Next() {
		var e dashdata.Employee
		if err := rows.Scan(&e.ID, &e.OrgID, &e.UserID, &e.NIF, &e.FullName, &e.Email, &e.Role,
			&e.Active, &e.ScheduleType, &e.VacationDaysAnnual, &e.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) ListUsers(ctx context.Context, orgID *uuid.UUID, search string, limit int) ([]dashdata.User, error) {
	if limit <= 0 {
		limit = 200
	}
	q := `
		SELECT u.id, u.org_id, o.legal_name, o.cif, u.email, u.role::text, u.created_at
		FROM users u
		JOIN organizations o ON o.id = u.org_id
		WHERE 1=1
	`
	args := []any{}
	n := 1
	if orgID != nil {
		q += fmt.Sprintf(` AND u.org_id = $%d`, n)
		args = append(args, *orgID)
		n++
	}
	if search != "" {
		q += fmt.Sprintf(` AND (u.email ILIKE $%d OR o.cif ILIKE $%d)`, n, n)
		args = append(args, "%"+search+"%")
	}
	q += ` ORDER BY u.created_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.User
	for rows.Next() {
		var u dashdata.User
		if err := rows.Scan(&u.ID, &u.OrgID, &u.OrgName, &u.OrgCIF, &u.Email, &u.Role, &u.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

func (s *Store) ListClockEvents(ctx context.Context, orgID *uuid.UUID, limit int) ([]dashdata.ClockEvent, error) {
	if limit <= 0 {
		limit = 100
	}
	q := `
		SELECT c.id, c.org_id, o.cif, o.legal_name, c.employee_id, e.full_name, e.nif,
			c.event_type::text, c.hour_type::text, c.recorded_at, c.is_correction
		FROM clock_events c
		JOIN organizations o ON o.id = c.org_id
		JOIN employees e ON e.id = c.employee_id
	`
	args := []any{}
	if orgID != nil {
		q += ` WHERE c.org_id = $1`
		args = append(args, *orgID)
	}
	q += ` ORDER BY c.recorded_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.ClockEvent
	for rows.Next() {
		var c dashdata.ClockEvent
		if err := rows.Scan(&c.ID, &c.OrgID, &c.OrgCIF, &c.OrgName, &c.EmployeeID, &c.Employee, &c.NIF,
			&c.EventType, &c.HourType, &c.RecordedAt, &c.IsCorrection); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) ListCorrections(ctx context.Context, orgID *uuid.UUID, status string, limit int) ([]dashdata.Correction, error) {
	if limit <= 0 {
		limit = 100
	}
	q := `
		SELECT cr.id, cr.org_id, o.cif, e.full_name, e.nif, cr.event_type::text,
			cr.proposed_at, cr.reason, cr.status::text, cr.created_at
		FROM correction_requests cr
		JOIN organizations o ON o.id = cr.org_id
		JOIN employees e ON e.id = cr.employee_id
		WHERE 1=1
	`
	args := []any{}
	n := 1
	if orgID != nil {
		q += fmt.Sprintf(` AND cr.org_id = $%d`, n)
		args = append(args, *orgID)
		n++
	}
	if status != "" {
		q += fmt.Sprintf(` AND cr.status = $%d::correction_status`, n)
		args = append(args, status)
	}
	q += ` ORDER BY cr.created_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.Correction
	for rows.Next() {
		var c dashdata.Correction
		if err := rows.Scan(&c.ID, &c.OrgID, &c.OrgCIF, &c.Employee, &c.NIF, &c.EventType,
			&c.ProposedAt, &c.Reason, &c.Status, &c.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) ListAbsences(ctx context.Context, orgID *uuid.UUID, status string, limit int) ([]dashdata.Absence, error) {
	if limit <= 0 {
		limit = 100
	}
	q := `
		SELECT ar.id, ar.org_id, o.cif, e.full_name, e.nif, ar.absence_type::text,
			ar.start_date, ar.end_date, ar.status::text, ar.reason, ar.created_at
		FROM absence_requests ar
		JOIN organizations o ON o.id = ar.org_id
		JOIN employees e ON e.id = ar.employee_id
		WHERE 1=1
	`
	args := []any{}
	n := 1
	if orgID != nil {
		q += fmt.Sprintf(` AND ar.org_id = $%d`, n)
		args = append(args, *orgID)
		n++
	}
	if status != "" {
		q += fmt.Sprintf(` AND ar.status = $%d::correction_status`, n)
		args = append(args, status)
	}
	q += ` ORDER BY ar.created_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.Absence
	for rows.Next() {
		var a dashdata.Absence
		if err := rows.Scan(&a.ID, &a.OrgID, &a.OrgCIF, &a.Employee, &a.NIF, &a.AbsenceType,
			&a.StartDate, &a.EndDate, &a.Status, &a.Reason, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (s *Store) ListAuditLog(ctx context.Context, orgID *uuid.UUID, limit int) ([]dashdata.AuditEntry, error) {
	if limit <= 0 {
		limit = 100
	}
	q := `
		SELECT a.id, a.org_id, o.cif, a.action, a.entity_type, a.entity_id,
			host(a.ip_address), a.created_at
		FROM audit_log a
		JOIN organizations o ON o.id = a.org_id
	`
	args := []any{}
	if orgID != nil {
		q += ` WHERE a.org_id = $1`
		args = append(args, *orgID)
	}
	q += ` ORDER BY a.created_at DESC LIMIT ` + fmt.Sprintf("%d", limit)

	rows, err := s.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []dashdata.AuditEntry
	for rows.Next() {
		var a dashdata.AuditEntry
		if err := rows.Scan(&a.ID, &a.OrgID, &a.OrgCIF, &a.Action, &a.EntityType, &a.EntityID,
			&a.IPAddress, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (s *Store) GetEmployee(ctx context.Context, id uuid.UUID) (*dashdata.Employee, error) {
	var e dashdata.Employee
	err := s.pool.QueryRow(ctx, `
		SELECT e.id, e.org_id, e.user_id, e.nif, e.full_name, u.email, u.role::text,
			e.active, e.schedule_type::text, e.vacation_days_annual, e.created_at
		FROM employees e
		LEFT JOIN users u ON u.id = e.user_id
		WHERE e.id = $1`, id,
	).Scan(&e.ID, &e.OrgID, &e.UserID, &e.NIF, &e.FullName, &e.Email, &e.Role,
		&e.Active, &e.ScheduleType, &e.VacationDaysAnnual, &e.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &e, nil
}

func (s *Store) SetEmployeeActive(ctx context.Context, employeeID uuid.UUID, active bool) error {
	_, err := s.pool.Exec(ctx, `UPDATE employees SET active = $1 WHERE id = $2`, active, employeeID)
	return err
}

func (s *Store) SetOrgTier(ctx context.Context, orgID uuid.UUID, tier string) error {
	_, err := s.pool.Exec(ctx, `UPDATE organizations SET subscription_tier = $1 WHERE id = $2`, tier, orgID)
	return err
}
