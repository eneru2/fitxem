package dashdata

import (
	"time"

	"github.com/google/uuid"
)

type Stats struct {
	OrgCount           int
	UserCount          int
	EmployeeCount      int
	ActiveEmployees    int
	ClockEventsToday   int
	ClockEventsTotal   int
	PendingCorrections int
	PendingAbsences    int
}

type Organization struct {
	ID               uuid.UUID
	CIF              string
	LegalName        string
	SubscriptionTier string
	StripeCustomerID *string
	CreatedAt        time.Time
	EmployeeCount    int
	UserCount        int
	ClockEventCount  int
}

type User struct {
	ID        uuid.UUID
	OrgID     uuid.UUID
	OrgName   string
	OrgCIF    string
	Email     string
	Role      string
	CreatedAt time.Time
}

type Employee struct {
	ID                 uuid.UUID
	OrgID              uuid.UUID
	UserID             *uuid.UUID
	NIF                string
	FullName           string
	Email              *string
	Role               *string
	Active             bool
	ScheduleType       string
	VacationDaysAnnual int
	CreatedAt          time.Time
}

type ClockEvent struct {
	ID           uuid.UUID
	OrgID        uuid.UUID
	OrgCIF       string
	OrgName      string
	EmployeeID   uuid.UUID
	Employee     string
	NIF          string
	EventType    string
	HourType     string
	RecordedAt   time.Time
	IsCorrection bool
}

type Correction struct {
	ID         uuid.UUID
	OrgID      uuid.UUID
	OrgCIF     string
	Employee   string
	NIF        string
	EventType  string
	ProposedAt time.Time
	Reason     string
	Status     string
	CreatedAt  time.Time
}

type Absence struct {
	ID          uuid.UUID
	OrgID       uuid.UUID
	OrgCIF      string
	Employee    string
	NIF         string
	AbsenceType string
	StartDate   time.Time
	EndDate     time.Time
	Status      string
	Reason      *string
	CreatedAt   time.Time
}

type AuditEntry struct {
	ID         uuid.UUID
	OrgID      uuid.UUID
	OrgCIF     string
	Action     string
	EntityType string
	EntityID   *uuid.UUID
	IPAddress  *string
	CreatedAt  time.Time
}
