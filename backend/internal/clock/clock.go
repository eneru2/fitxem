package clock

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/eneru2/just-clock/internal/tsa"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrInvalidTransition = errors.New("invalid clock transition")
	ErrEmployeeNotFound  = errors.New("employee not found")
)

type EventType string

const (
	EventIn         EventType = "in"
	EventOut        EventType = "out"
	EventBreakStart EventType = "break_start"
	EventBreakEnd   EventType = "break_end"
)

type Service struct {
	pool *pgxpool.Pool
	tsa  tsa.Client
}

func NewService(pool *pgxpool.Pool, tsaClient tsa.Client) *Service {
	return &Service{pool: pool, tsa: tsaClient}
}

type ClockEvent struct {
	ID           uuid.UUID  `json:"id"`
	OrgID        uuid.UUID  `json:"org_id"`
	EmployeeID   uuid.UUID  `json:"employee_id"`
	EventType    EventType  `json:"event_type"`
	HourType     string     `json:"hour_type"`
	RecordedAt   time.Time  `json:"recorded_at"`
	ClientAt     *time.Time `json:"client_at,omitempty"`
	WorkCenterID *uuid.UUID `json:"work_center_id,omitempty"`
	Latitude     *float64   `json:"latitude,omitempty"`
	Longitude    *float64   `json:"longitude,omitempty"`
	PrevHash     string     `json:"prev_hash"`
	EventHash    string     `json:"event_hash"`
	IsCorrection bool       `json:"is_correction"`
	WorkCenter         string   `json:"work_center,omitempty"`
	WorkCenterAddress  string   `json:"work_center_address,omitempty"`
	WorkCenterLatitude  *float64 `json:"work_center_latitude,omitempty"`
	WorkCenterLongitude *float64 `json:"work_center_longitude,omitempty"`
}

type RecordInput struct {
	OrgID               uuid.UUID
	EmployeeID          uuid.UUID
	EventType           EventType
	ClientAt            *time.Time
	HourType            string
	Latitude            *float64
	Longitude           *float64
	IsCorrection        bool
	CorrectionRequestID *uuid.UUID
}

func ValidateCoordinates(lat, lng *float64) error {
	if lat == nil && lng == nil {
		return nil
	}
	if lat == nil || lng == nil {
		return errors.New("latitude and longitude must both be provided")
	}
	if *lat < -90 || *lat > 90 || *lng < -180 || *lng > 180 {
		return errors.New("invalid coordinates")
	}
	return nil
}

func (s *Service) Record(ctx context.Context, in RecordInput) (*ClockEvent, error) {
	if in.HourType == "" {
		in.HourType = "ordinary"
	}

	employee, err := s.getEmployee(ctx, in.OrgID, in.EmployeeID)
	if err != nil {
		return nil, err
	}

	last, err := s.lastEvent(ctx, in.OrgID, in.EmployeeID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	if !in.IsCorrection {
		if err := validateTransition(last, in.EventType); err != nil {
			return nil, err
		}
	}

	prevHash := ""
	if last != nil {
		prevHash = last.EventHash
	}

	recordedAt := time.Now().UTC()
	eventID := uuid.New()

	payload := hashPayload{
		ID:         eventID.String(),
		OrgID:      in.OrgID.String(),
		EmployeeID: in.EmployeeID.String(),
		EventType:  string(in.EventType),
		HourType:   in.HourType,
		RecordedAt: recordedAt.Format(time.RFC3339Nano),
		PrevHash:   prevHash,
	}
	if in.ClientAt != nil {
		payload.ClientAt = in.ClientAt.Format(time.RFC3339Nano)
	}
	if in.Latitude != nil && in.Longitude != nil {
		payload.Latitude = fmt.Sprintf("%g", *in.Latitude)
		payload.Longitude = fmt.Sprintf("%g", *in.Longitude)
	}

	eventHash, err := computeHash(payload)
	if err != nil {
		return nil, err
	}

	tsaToken, err := s.tsa.Timestamp(ctx, []byte(eventHash))
	if err != nil {
		return nil, fmt.Errorf("tsa: %w", err)
	}

	var ev ClockEvent
	err = s.pool.QueryRow(ctx, `
		INSERT INTO clock_events (
			id, org_id, employee_id, event_type, hour_type, recorded_at, client_at,
			work_center_id, latitude, longitude, prev_hash, event_hash, tsa_token,
			is_correction, correction_request_id
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
		RETURNING id, org_id, employee_id, event_type::text, hour_type::text, recorded_at,
			client_at, work_center_id, latitude, longitude, prev_hash, event_hash, is_correction`,
		eventID, in.OrgID, in.EmployeeID, in.EventType, in.HourType, recordedAt, in.ClientAt,
		employee.WorkCenterID, in.Latitude, in.Longitude, prevHash, eventHash, tsaToken,
		in.IsCorrection, in.CorrectionRequestID,
	).Scan(
		&ev.ID, &ev.OrgID, &ev.EmployeeID, &ev.EventType, &ev.HourType, &ev.RecordedAt,
		&ev.ClientAt, &ev.WorkCenterID, &ev.Latitude, &ev.Longitude,
		&ev.PrevHash, &ev.EventHash, &ev.IsCorrection,
	)
	if err != nil {
		return nil, err
	}
	return &ev, nil
}

type TodaySummary struct {
	EmployeeID    uuid.UUID    `json:"employee_id"`
	Events        []ClockEvent `json:"events"`
	WorkedSeconds int64        `json:"worked_seconds"`
	AsOf          time.Time    `json:"as_of"`
}

func (s *Service) TodaySummary(ctx context.Context, orgID, employeeID uuid.UUID) (*TodaySummary, error) {
	events, err := s.TodayStatus(ctx, orgID, employeeID)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	return &TodaySummary{
		EmployeeID:    employeeID,
		Events:        events,
		WorkedSeconds: WorkedSeconds(events, now),
		AsOf:          now,
	}, nil
}

func (s *Service) TodayStatus(ctx context.Context, orgID, employeeID uuid.UUID) ([]ClockEvent, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, org_id, employee_id, event_type::text, hour_type::text, recorded_at,
			client_at, work_center_id, latitude, longitude, prev_hash, event_hash, is_correction
		FROM clock_events
		WHERE org_id = $1 AND employee_id = $2
		  AND recorded_at >= (
		    date_trunc('day', NOW() AT TIME ZONE 'Europe/Madrid') AT TIME ZONE 'Europe/Madrid'
		  )
		ORDER BY recorded_at ASC`,
		orgID, employeeID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanEvents(rows)
}

func WorkedSeconds(events []ClockEvent, now time.Time) int64 {
	var workStart *time.Time
	var total time.Duration

	for _, ev := range events {
		at := ev.RecordedAt
		switch ev.EventType {
		case EventIn, EventBreakEnd:
			workStart = &at
		case EventOut, EventBreakStart:
			if workStart != nil {
				total += at.Sub(*workStart)
				workStart = nil
			}
		}
	}
	if workStart != nil {
		total += now.Sub(*workStart)
	}
	return int64(total.Seconds())
}

func (s *Service) ListRecords(ctx context.Context, orgID, employeeID uuid.UUID, from, to time.Time) ([]ClockEvent, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT ce.id, ce.org_id, ce.employee_id, ce.event_type::text, ce.hour_type::text,
			ce.recorded_at, ce.client_at, ce.work_center_id, ce.latitude, ce.longitude,
			ce.prev_hash, ce.event_hash, ce.is_correction,
			wc.name, COALESCE(wc.address, ''), wc.latitude, wc.longitude
		FROM clock_events ce
		LEFT JOIN work_centers wc ON wc.id = ce.work_center_id
		WHERE ce.org_id = $1 AND ce.employee_id = $2
		  AND ce.recorded_at >= $3 AND ce.recorded_at <= $4
		ORDER BY ce.recorded_at ASC`,
		orgID, employeeID, from, to,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanEnrichedEvents(rows)
}

func (s *Service) ListOrgRecords(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]ClockEventWithEmployee, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT ce.id, ce.org_id, ce.employee_id, ce.event_type::text, ce.hour_type::text,
			ce.recorded_at, ce.client_at, ce.work_center_id, ce.prev_hash, ce.event_hash,
			ce.is_correction, e.nif, e.full_name, wc.name
		FROM clock_events ce
		JOIN employees e ON e.id = ce.employee_id
		LEFT JOIN work_centers wc ON wc.id = ce.work_center_id
		WHERE ce.org_id = $1 AND ce.recorded_at >= $2 AND ce.recorded_at <= $3
		ORDER BY ce.recorded_at ASC`,
		orgID, from, to,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []ClockEventWithEmployee
	for rows.Next() {
		var ev ClockEventWithEmployee
		var wcName *string
		err := rows.Scan(
			&ev.ID, &ev.OrgID, &ev.EmployeeID, &ev.EventType, &ev.HourType,
			&ev.RecordedAt, &ev.ClientAt, &ev.WorkCenterID, &ev.PrevHash, &ev.EventHash,
			&ev.IsCorrection, &ev.EmployeeNIF, &ev.EmployeeName, &wcName,
		)
		if err != nil {
			return nil, err
		}
		if wcName != nil {
			ev.WorkCenterName = *wcName
		}
		out = append(out, ev)
	}
	return out, rows.Err()
}

type ClockEventWithEmployee struct {
	ClockEvent
	EmployeeNIF    string `json:"employee_nif"`
	EmployeeName   string `json:"employee_name"`
	WorkCenterName string `json:"work_center,omitempty"`
}

type employeeRow struct {
	ID            uuid.UUID
	WorkCenterID  *uuid.UUID
}

func (s *Service) getEmployee(ctx context.Context, orgID, employeeID uuid.UUID) (*employeeRow, error) {
	var e employeeRow
	err := s.pool.QueryRow(ctx,
		`SELECT id, work_center_id FROM employees WHERE org_id = $1 AND id = $2 AND active = true`,
		orgID, employeeID,
	).Scan(&e.ID, &e.WorkCenterID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrEmployeeNotFound
		}
		return nil, err
	}
	return &e, nil
}

func (s *Service) lastEvent(ctx context.Context, orgID, employeeID uuid.UUID) (*ClockEvent, error) {
	var ev ClockEvent
	err := s.pool.QueryRow(ctx, `
		SELECT id, org_id, employee_id, event_type::text, hour_type::text, recorded_at,
			client_at, work_center_id, latitude, longitude, prev_hash, event_hash, is_correction
		FROM clock_events
		WHERE org_id = $1 AND employee_id = $2
		ORDER BY recorded_at DESC LIMIT 1`,
		orgID, employeeID,
	).Scan(
		&ev.ID, &ev.OrgID, &ev.EmployeeID, &ev.EventType, &ev.HourType, &ev.RecordedAt,
		&ev.ClientAt, &ev.WorkCenterID, &ev.Latitude, &ev.Longitude,
		&ev.PrevHash, &ev.EventHash, &ev.IsCorrection,
	)
	if err != nil {
		return nil, err
	}
	return &ev, nil
}

func (s *Service) EmployeeIDForUser(ctx context.Context, orgID, userID uuid.UUID) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT id FROM employees WHERE org_id = $1 AND user_id = $2`,
		orgID, userID,
	).Scan(&id)
	return id, err
}

func validateTransition(last *ClockEvent, next EventType) error {
	if last == nil {
		if next != EventIn {
			return ErrInvalidTransition
		}
		return nil
	}
	allowed := map[EventType][]EventType{
		EventIn:         {EventOut, EventBreakStart},
		EventBreakStart: {EventBreakEnd},
		EventBreakEnd:   {EventOut, EventBreakStart},
		EventOut:        {EventIn},
	}
	for _, a := range allowed[last.EventType] {
		if a == next {
			return nil
		}
	}
	return ErrInvalidTransition
}

type hashPayload struct {
	ID         string `json:"id"`
	OrgID      string `json:"org_id"`
	EmployeeID string `json:"employee_id"`
	EventType  string `json:"event_type"`
	HourType   string `json:"hour_type"`
	RecordedAt string `json:"recorded_at"`
	ClientAt   string `json:"client_at,omitempty"`
	Latitude   string `json:"latitude,omitempty"`
	Longitude  string `json:"longitude,omitempty"`
	PrevHash   string `json:"prev_hash"`
}

func computeHash(p hashPayload) (string, error) {
	b, err := json.Marshal(p)
	if err != nil {
		return "", err
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:]), nil
}

type rowScanner interface {
	Next() bool
	Scan(dest ...any) error
	Err() error
}

func scanEvents(rows rowScanner) ([]ClockEvent, error) {
	var out []ClockEvent
	for rows.Next() {
		var ev ClockEvent
		if err := rows.Scan(
			&ev.ID, &ev.OrgID, &ev.EmployeeID, &ev.EventType, &ev.HourType, &ev.RecordedAt,
			&ev.ClientAt, &ev.WorkCenterID, &ev.Latitude, &ev.Longitude,
			&ev.PrevHash, &ev.EventHash, &ev.IsCorrection,
		); err != nil {
			return nil, err
		}
		out = append(out, ev)
	}
	return out, rows.Err()
}

func scanEnrichedEvents(rows rowScanner) ([]ClockEvent, error) {
	var out []ClockEvent
	for rows.Next() {
		var ev ClockEvent
		var wcName *string
		var wcAddress string
		var wcLat, wcLng *float64
		if err := rows.Scan(
			&ev.ID, &ev.OrgID, &ev.EmployeeID, &ev.EventType, &ev.HourType, &ev.RecordedAt,
			&ev.ClientAt, &ev.WorkCenterID, &ev.Latitude, &ev.Longitude,
			&ev.PrevHash, &ev.EventHash, &ev.IsCorrection,
			&wcName, &wcAddress, &wcLat, &wcLng,
		); err != nil {
			return nil, err
		}
		if wcName != nil {
			ev.WorkCenter = *wcName
		}
		ev.WorkCenterAddress = wcAddress
		ev.WorkCenterLatitude = wcLat
		ev.WorkCenterLongitude = wcLng
		out = append(out, ev)
	}
	return out, rows.Err()
}
