package handlers_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/eneru2/just-clock/internal/absence"
	"github.com/eneru2/just-clock/internal/auth"
	"github.com/eneru2/just-clock/internal/billing"
	"github.com/eneru2/just-clock/internal/clock"
	"github.com/eneru2/just-clock/internal/compliance"
	"github.com/eneru2/just-clock/internal/correction"
	"github.com/eneru2/just-clock/internal/tsa"
	"github.com/eneru2/just-clock/internal/config"
	"github.com/eneru2/just-clock/internal/db"
	"github.com/eneru2/just-clock/internal/handlers"
	"github.com/eneru2/just-clock/internal/itss"
	"github.com/eneru2/just-clock/internal/middleware"
	"github.com/eneru2/just-clock/internal/org"
	"github.com/go-chi/chi/v5"
)

func setupTestAPI(t *testing.T) (*handlers.API, *auth.Service, func()) {
	t.Helper()
	cfg := config.Load()
	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		t.Skipf("postgres not available: %v", err)
	}

	tsaClient := tsa.NewClient("mock")
	authSvc := auth.NewService(pool, cfg.JWTSecret, cfg.JWTAccessTTL, cfg.JWTRefreshTTL)
	clockSvc := clock.NewService(pool, tsaClient)
	orgSvc := org.NewService(pool)
	auditSvc := compliance.NewAuditService(pool)
	exportSvc := compliance.NewExportService(pool, clockSvc)
	correctionSvc := correction.NewService(pool, clockSvc)
	absenceSvc := absence.NewService(pool)
	itssSvc := itss.NewService(pool, clockSvc, auditSvc)
	billingSvc := billing.NewService("", orgSvc)

	api := &handlers.API{
		Auth: authSvc, Clock: clockSvc, Org: orgSvc, ExportSvc: exportSvc,
		Correction: correctionSvc, Absence: absenceSvc, Audit: auditSvc, ITSS: itssSvc, Billing: billingSvc,
	}
	return api, authSvc, func() { pool.Close() }
}

func TestHealth(t *testing.T) {
	api, _, cleanup := setupTestAPI(t)
	defer cleanup()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	api.Health(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
}

func TestRegisterAndClockFlow(t *testing.T) {
	api, _, cleanup := setupTestAPI(t)
	defer cleanup()

	suffix := time.Now().UnixNano()
	body := map[string]string{
		"cif":            "B99999999",
		"legal_name":     "Test SL",
		"owner_email":    "owner@test.com",
		"owner_password": "secret123",
		"owner_name":     "Owner Test",
		"owner_nif":      "12345678Z",
	}
	body["owner_email"] = "owner" + string(rune(suffix%26+97)) + "@test.com"
	b, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/auth/register-org", bytes.NewReader(b))
	w := httptest.NewRecorder()
	api.RegisterOrg(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("register status %d: %s", w.Code, w.Body.String())
	}

	var reg struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.NewDecoder(w.Body).Decode(&reg)

	r := chi.NewRouter()
	r.Use(middleware.Auth(api.Auth))
	r.Post("/clock/in", api.ClockIn)
	r.Get("/me/today", api.MeToday)

	req = httptest.NewRequest(http.MethodPost, "/clock/in", nil)
	req.Header.Set("Authorization", "Bearer "+reg.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("clock in status %d: %s", w.Code, w.Body.String())
	}

	req = httptest.NewRequest(http.MethodGet, "/me/today", nil)
	req.Header.Set("Authorization", "Bearer "+reg.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("me/today status %d: %s", w.Code, w.Body.String())
	}
	var today struct {
		Events []struct {
			EventType string `json:"event_type"`
		} `json:"events"`
		WorkedSeconds int64  `json:"worked_seconds"`
		AsOf          string `json:"as_of"`
	}
	if err := json.NewDecoder(w.Body).Decode(&today); err != nil {
		t.Fatal(err)
	}
	if len(today.Events) == 0 {
		t.Fatal("expected today's events after clock in")
	}
	if today.Events[len(today.Events)-1].EventType != "in" {
		t.Fatalf("last event type %q, want in", today.Events[len(today.Events)-1].EventType)
	}
	if today.WorkedSeconds < 0 {
		t.Fatalf("worked_seconds %d, want >= 0", today.WorkedSeconds)
	}
	if today.AsOf == "" {
		t.Fatal("expected as_of timestamp")
	}
}
