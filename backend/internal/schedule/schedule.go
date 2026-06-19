package schedule

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound      = errors.New("schedule template not found")
	ErrInvalidType   = errors.New("invalid schedule type")
	ErrInvalidSlot   = errors.New("invalid schedule slot")
	ErrEmployeeNotFound = errors.New("employee not found")
)

type Service struct {
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

type Slot struct {
	DayOfWeek int    `json:"day_of_week"`
	StartTime string `json:"start_time"`
	EndTime   string `json:"end_time"`
}

type Template struct {
	ID           uuid.UUID `json:"id"`
	OrgID        uuid.UUID `json:"org_id"`
	Name         string    `json:"name"`
	ScheduleType string    `json:"schedule_type"`
	WeeklyHours  *float64  `json:"weekly_hours,omitempty"`
	Slots        []Slot    `json:"slots,omitempty"`
}

type EmployeeSchedule struct {
	ScheduleType       string   `json:"schedule_type"`
	ScheduleTemplateID *uuid.UUID `json:"schedule_template_id,omitempty"`
	WeeklyHours        *float64 `json:"weekly_hours,omitempty"`
	Timezone           string   `json:"timezone"`
	Slots              []Slot   `json:"slots"`
}

type CreateTemplateInput struct {
	OrgID        uuid.UUID
	Name         string
	ScheduleType string
	WeeklyHours  *float64
	Slots        []Slot
}

type UpdateTemplateInput struct {
	OrgID        uuid.UUID
	TemplateID   uuid.UUID
	Name         string
	ScheduleType string
	WeeklyHours  *float64
	Slots        []Slot
}

type AssignScheduleInput struct {
	OrgID              uuid.UUID
	EmployeeID         uuid.UUID
	ScheduleType       string
	ScheduleTemplateID *uuid.UUID
	WeeklyHours        *float64
	Slots              []Slot
	VacationDaysAnnual *int
}

func validTemplateType(t string) bool {
	return t == "fixed" || t == "flexible"
}

func validEmployeeScheduleType(t string) bool {
	switch t {
	case "none", "template", "custom", "flexible":
		return true
	default:
		return false
	}
}

func parseTime(s string) (time.Time, error) {
	t, err := time.Parse("15:04", s)
	if err != nil {
		t, err = time.Parse("15:04:05", s)
	}
	return t, err
}

func validateSlots(slots []Slot) error {
	for _, sl := range slots {
		if sl.DayOfWeek < 0 || sl.DayOfWeek > 6 {
			return ErrInvalidSlot
		}
		start, err := parseTime(sl.StartTime)
		if err != nil {
			return ErrInvalidSlot
		}
		end, err := parseTime(sl.EndTime)
		if err != nil {
			return ErrInvalidSlot
		}
		if !end.After(start) {
			return ErrInvalidSlot
		}
	}
	return nil
}

func formatTime(t time.Time) string {
	return t.Format("15:04")
}

func (s *Service) ListTemplates(ctx context.Context, orgID uuid.UUID) ([]Template, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, org_id, name, schedule_type::text, weekly_hours
		FROM schedule_templates WHERE org_id = $1 ORDER BY name`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Template
	for rows.Next() {
		var t Template
		if err := rows.Scan(&t.ID, &t.OrgID, &t.Name, &t.ScheduleType, &t.WeeklyHours); err != nil {
			return nil, err
		}
		slots, err := s.loadTemplateSlots(ctx, t.ID)
		if err != nil {
			return nil, err
		}
		t.Slots = slots
		out = append(out, t)
	}
	return out, rows.Err()
}

func (s *Service) loadTemplateSlots(ctx context.Context, templateID uuid.UUID) ([]Slot, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT day_of_week, start_time, end_time
		FROM schedule_template_slots WHERE template_id = $1 ORDER BY day_of_week, start_time`, templateID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var slots []Slot
	for rows.Next() {
		var sl Slot
		var start, end time.Time
		if err := rows.Scan(&sl.DayOfWeek, &start, &end); err != nil {
			return nil, err
		}
		sl.StartTime = formatTime(start)
		sl.EndTime = formatTime(end)
		slots = append(slots, sl)
	}
	return slots, rows.Err()
}

func (s *Service) CreateTemplate(ctx context.Context, in CreateTemplateInput) (*Template, error) {
	if !validTemplateType(in.ScheduleType) {
		return nil, ErrInvalidType
	}
	if in.ScheduleType == "fixed" {
		if err := validateSlots(in.Slots); err != nil {
			return nil, err
		}
	} else if in.WeeklyHours == nil || *in.WeeklyHours <= 0 {
		return nil, fmt.Errorf("weekly_hours required for flexible template")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var t Template
	err = tx.QueryRow(ctx, `
		INSERT INTO schedule_templates (org_id, name, schedule_type, weekly_hours)
		VALUES ($1, $2, $3::schedule_template_type, $4)
		RETURNING id, org_id, name, schedule_type::text, weekly_hours`,
		in.OrgID, in.Name, in.ScheduleType, in.WeeklyHours,
	).Scan(&t.ID, &t.OrgID, &t.Name, &t.ScheduleType, &t.WeeklyHours)
	if err != nil {
		return nil, err
	}

	if in.ScheduleType == "fixed" {
		for _, sl := range in.Slots {
			start, _ := parseTime(sl.StartTime)
			end, _ := parseTime(sl.EndTime)
			_, err = tx.Exec(ctx, `
				INSERT INTO schedule_template_slots (template_id, day_of_week, start_time, end_time)
				VALUES ($1, $2, $3, $4)`,
				t.ID, sl.DayOfWeek, start, end,
			)
			if err != nil {
				return nil, err
			}
		}
		t.Slots = in.Slots
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &t, nil
}

func (s *Service) UpdateTemplate(ctx context.Context, in UpdateTemplateInput) (*Template, error) {
	if !validTemplateType(in.ScheduleType) {
		return nil, ErrInvalidType
	}
	if in.ScheduleType == "fixed" {
		if err := validateSlots(in.Slots); err != nil {
			return nil, err
		}
	} else if in.WeeklyHours == nil || *in.WeeklyHours <= 0 {
		return nil, fmt.Errorf("weekly_hours required for flexible template")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var t Template
	err = tx.QueryRow(ctx, `
		UPDATE schedule_templates
		SET name = $1, schedule_type = $2::schedule_template_type, weekly_hours = $3
		WHERE id = $4 AND org_id = $5
		RETURNING id, org_id, name, schedule_type::text, weekly_hours`,
		in.Name, in.ScheduleType, in.WeeklyHours, in.TemplateID, in.OrgID,
	).Scan(&t.ID, &t.OrgID, &t.Name, &t.ScheduleType, &t.WeeklyHours)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	_, err = tx.Exec(ctx, `DELETE FROM schedule_template_slots WHERE template_id = $1`, t.ID)
	if err != nil {
		return nil, err
	}

	if in.ScheduleType == "fixed" {
		for _, sl := range in.Slots {
			start, _ := parseTime(sl.StartTime)
			end, _ := parseTime(sl.EndTime)
			_, err = tx.Exec(ctx, `
				INSERT INTO schedule_template_slots (template_id, day_of_week, start_time, end_time)
				VALUES ($1, $2, $3, $4)`,
				t.ID, sl.DayOfWeek, start, end,
			)
			if err != nil {
				return nil, err
			}
		}
		t.Slots = in.Slots
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &t, nil
}

func (s *Service) DeleteTemplate(ctx context.Context, orgID, templateID uuid.UUID) error {
	tag, err := s.pool.Exec(ctx,
		`DELETE FROM schedule_templates WHERE id = $1 AND org_id = $2`, templateID, orgID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Service) AssignEmployeeSchedule(ctx context.Context, in AssignScheduleInput) (*EmployeeSchedule, error) {
	if !validEmployeeScheduleType(in.ScheduleType) {
		return nil, ErrInvalidType
	}

	switch in.ScheduleType {
	case "template":
		if in.ScheduleTemplateID == nil {
			return nil, fmt.Errorf("schedule_template_id required")
		}
	case "custom":
		if err := validateSlots(in.Slots); err != nil {
			return nil, err
		}
	case "flexible":
		if in.WeeklyHours == nil || *in.WeeklyHours <= 0 {
			return nil, fmt.Errorf("weekly_hours required for flexible schedule")
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var exists int
	err = tx.QueryRow(ctx,
		`SELECT 1 FROM employees WHERE id = $1 AND org_id = $2`, in.EmployeeID, in.OrgID,
	).Scan(&exists)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrEmployeeNotFound
		}
		return nil, err
	}

	if in.ScheduleType == "template" {
		err = tx.QueryRow(ctx,
			`SELECT 1 FROM schedule_templates WHERE id = $1 AND org_id = $2`,
			in.ScheduleTemplateID, in.OrgID,
		).Scan(&exists)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, ErrNotFound
			}
			return nil, err
		}
	}

	if in.VacationDaysAnnual != nil {
		_, err = tx.Exec(ctx,
			`UPDATE employees SET vacation_days_annual = $1 WHERE id = $2 AND org_id = $3`,
			*in.VacationDaysAnnual, in.EmployeeID, in.OrgID,
		)
		if err != nil {
			return nil, err
		}
	}

	_, err = tx.Exec(ctx, `
		UPDATE employees
		SET schedule_type = $1::employee_schedule_type,
			schedule_template_id = $2,
			weekly_hours = $3
		WHERE id = $4 AND org_id = $5`,
		in.ScheduleType, in.ScheduleTemplateID, in.WeeklyHours, in.EmployeeID, in.OrgID,
	)
	if err != nil {
		return nil, err
	}

	_, err = tx.Exec(ctx, `DELETE FROM employee_schedule_slots WHERE employee_id = $1`, in.EmployeeID)
	if err != nil {
		return nil, err
	}

	if in.ScheduleType == "custom" {
		for _, sl := range in.Slots {
			start, _ := parseTime(sl.StartTime)
			end, _ := parseTime(sl.EndTime)
			_, err = tx.Exec(ctx, `
				INSERT INTO employee_schedule_slots (employee_id, day_of_week, start_time, end_time)
				VALUES ($1, $2, $3, $4)`,
				in.EmployeeID, sl.DayOfWeek, start, end,
			)
			if err != nil {
				return nil, err
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return s.GetEmployeeSchedule(ctx, in.OrgID, in.EmployeeID)
}

func (s *Service) employeeTimezone(ctx context.Context, employeeID uuid.UUID) string {
	var tz string
	err := s.pool.QueryRow(ctx, `
		SELECT COALESCE(wc.timezone, 'Europe/Madrid')
		FROM employees e
		LEFT JOIN work_centers wc ON wc.id = e.work_center_id
		WHERE e.id = $1`, employeeID,
	).Scan(&tz)
	if err != nil || tz == "" {
		return "Europe/Madrid"
	}
	return tz
}

func (s *Service) loadEmployeeSlots(ctx context.Context, employeeID uuid.UUID) ([]Slot, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT day_of_week, start_time, end_time
		FROM employee_schedule_slots WHERE employee_id = $1 ORDER BY day_of_week, start_time`, employeeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var slots []Slot
	for rows.Next() {
		var sl Slot
		var start, end time.Time
		if err := rows.Scan(&sl.DayOfWeek, &start, &end); err != nil {
			return nil, err
		}
		sl.StartTime = formatTime(start)
		sl.EndTime = formatTime(end)
		slots = append(slots, sl)
	}
	return slots, rows.Err()
}

func (s *Service) GetEmployeeSchedule(ctx context.Context, orgID, employeeID uuid.UUID) (*EmployeeSchedule, error) {
	var sched EmployeeSchedule
	var templateID *uuid.UUID
	err := s.pool.QueryRow(ctx, `
		SELECT schedule_type::text, schedule_template_id, weekly_hours
		FROM employees WHERE id = $1 AND org_id = $2`, employeeID, orgID,
	).Scan(&sched.ScheduleType, &templateID, &sched.WeeklyHours)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrEmployeeNotFound
		}
		return nil, err
	}
	sched.ScheduleTemplateID = templateID
	sched.Timezone = s.employeeTimezone(ctx, employeeID)

	switch sched.ScheduleType {
	case "template":
		if templateID == nil {
			sched.Slots = []Slot{}
			break
		}
		slots, err := s.loadTemplateSlots(ctx, *templateID)
		if err != nil {
			return nil, err
		}
		sched.Slots = slots
	case "custom":
		slots, err := s.loadEmployeeSlots(ctx, employeeID)
		if err != nil {
			return nil, err
		}
		sched.Slots = slots
	default:
		sched.Slots = []Slot{}
	}

	return &sched, nil
}
