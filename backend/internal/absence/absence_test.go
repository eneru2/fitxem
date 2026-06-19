package absence

import (
	"testing"
	"time"
)

func TestCountVacationDays(t *testing.T) {
	// Mon 2025-06-16 to Fri 2025-06-20 = 5 working days
	start := time.Date(2025, 6, 16, 0, 0, 0, 0, time.UTC)
	end := time.Date(2025, 6, 20, 0, 0, 0, 0, time.UTC)
	if got := CountVacationDays(start, end); got != 5 {
		t.Fatalf("expected 5, got %d", got)
	}

	// Sat-Sun only = 0
	sat := time.Date(2025, 6, 21, 0, 0, 0, 0, time.UTC)
	sun := time.Date(2025, 6, 22, 0, 0, 0, 0, time.UTC)
	if got := CountVacationDays(sat, sun); got != 0 {
		t.Fatalf("expected 0 weekend days, got %d", got)
	}
}
