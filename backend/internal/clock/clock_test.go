package clock_test

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/eneru2/just-clock/internal/clock"
	"github.com/google/uuid"
)

type hashPayload struct {
	ID         string `json:"id"`
	OrgID      string `json:"org_id"`
	EmployeeID string `json:"employee_id"`
	EventType  string `json:"event_type"`
	HourType   string `json:"hour_type"`
	RecordedAt string `json:"recorded_at"`
	PrevHash   string `json:"prev_hash"`
}

func TestHashPayloadCanonical(t *testing.T) {
	p := hashPayload{
		ID: "test", OrgID: "org", EmployeeID: "emp",
		EventType: "in", HourType: "ordinary",
		RecordedAt: "2026-01-01T08:00:00Z", PrevHash: "",
	}
	b, err := json.Marshal(p)
	if err != nil {
		t.Fatal(err)
	}
	if len(b) == 0 {
		t.Fatal("empty hash payload")
	}
}

func TestWorkedSeconds(t *testing.T) {
	t0 := time.Date(2026, 6, 14, 8, 0, 0, 0, time.UTC)
	t1 := t0.Add(2 * time.Hour)
	t2 := t1.Add(30 * time.Minute)
	t3 := t2.Add(1 * time.Hour)
	now := t3.Add(45 * time.Minute)

	events := []clock.ClockEvent{
		{EventType: clock.EventIn, RecordedAt: t0},
		{EventType: clock.EventBreakStart, RecordedAt: t1},
		{EventType: clock.EventBreakEnd, RecordedAt: t2},
	}

	got := clock.WorkedSeconds(events, now)
	want := int64((3*time.Hour + 45*time.Minute).Seconds())
	if got != want {
		t.Fatalf("WorkedSeconds() = %d, want %d", got, want)
	}
}

func TestWorkedSecondsClosedDay(t *testing.T) {
	t0 := time.Date(2026, 6, 14, 9, 0, 0, 0, time.UTC)
	t1 := t0.Add(8 * time.Hour)
	now := t1.Add(2 * time.Hour)

	events := []clock.ClockEvent{
		{ID: uuid.New(), EventType: clock.EventIn, RecordedAt: t0},
		{ID: uuid.New(), EventType: clock.EventOut, RecordedAt: t1},
	}

	got := clock.WorkedSeconds(events, now)
	want := int64((8 * time.Hour).Seconds())
	if got != want {
		t.Fatalf("WorkedSeconds() = %d, want %d", got, want)
	}
}
