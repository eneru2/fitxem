package clock_test

import (
	"testing"

	"github.com/eneru2/just-clock/internal/clock"
)

func TestValidateCoordinates(t *testing.T) {
	lat, lng := 41.35, 2.08
	if err := clock.ValidateCoordinates(&lat, &lng); err != nil {
		t.Fatalf("valid coords: %v", err)
	}
	if err := clock.ValidateCoordinates(nil, nil); err != nil {
		t.Fatalf("nil coords: %v", err)
	}
	latOnly := 1.0
	if err := clock.ValidateCoordinates(&latOnly, nil); err == nil {
		t.Fatal("expected error for partial coords")
	}
	badLat := 91.0
	if err := clock.ValidateCoordinates(&badLat, &lng); err == nil {
		t.Fatal("expected error for invalid latitude")
	}
}
