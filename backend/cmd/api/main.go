package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/eneru2/just-clock/dashboard"
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
	"github.com/eneru2/just-clock/internal/schedule"
	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

func main() {
	cfg := config.Load()
	ctx := context.Background()

	if err := db.Migrate(cfg.DatabaseURL, "migrations"); err != nil {
		log.Fatalf("database migrate: %v", err)
	}

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database unavailable: %v", err)
	}
	defer pool.Close()

	tsaClient := tsa.NewClient(cfg.TSAURL)
	authSvc := auth.NewService(pool, cfg.JWTSecret, cfg.JWTAccessTTL, cfg.JWTRefreshTTL)
	clockSvc := clock.NewService(pool, tsaClient)
	orgSvc := org.NewService(pool)
	auditSvc := compliance.NewAuditService(pool)
	exportSvc := compliance.NewExportService(pool, clockSvc)
	correctionSvc := correction.NewService(pool, clockSvc)
	absenceSvc := absence.NewService(pool)
	scheduleSvc := schedule.NewService(pool)
	itssSvc := itss.NewService(pool, clockSvc, auditSvc)
	billingSvc := billing.NewService(cfg.StripeSecret, orgSvc)

	api := &handlers.API{
		Auth: authSvc, Clock: clockSvc, Org: orgSvc, ExportSvc: exportSvc,
		Correction: correctionSvc, Absence: absenceSvc, Schedule: scheduleSvc,
		Audit: auditSvc, ITSS: itssSvc, Billing: billingSvc,
	}

	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)
	r.Use(middleware.SecurityHeaders)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.CORSOrigins,
		AllowedMethods:   []string{"GET", "POST", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-ITSS-API-Key"},
		AllowCredentials: true,
	}))

	r.Get("/health", api.Health)

	r.Route("/auth", func(r chi.Router) {
		r.Post("/register-org", api.RegisterOrg)
		r.Post("/login", api.Login)
		r.Post("/refresh", api.Refresh)
	})

	r.Route("/itss/v1", func(r chi.Router) {
		r.Use(middleware.ITSSAuth(cfg.ITSSAPIKey))
		r.Get("/companies/{cif}/records", api.ITSSRecords)
		r.Get("/companies/{cif}/employees/{nif}/records", api.ITSSEmployeeRecords)
		r.Get("/companies/{cif}/audit-log", api.ITSSAuditLog)
	})

	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(authSvc))
		r.Get("/me/org", api.GetOrg)
		r.Get("/me/today", api.MeToday)
		r.Get("/me/records", api.MeRecords)
		r.Post("/clock/in", api.ClockIn)
		r.Post("/clock/out", api.ClockOut)
		r.Post("/clock/break/start", api.BreakStart)
		r.Post("/clock/break/end", api.BreakEnd)
		r.Post("/corrections", api.CreateCorrection)
		r.Get("/me/corrections", api.ListMyCorrections)
		r.Post("/absences", api.CreateAbsence)
		r.Get("/me/absences", api.ListMyAbsences)
		r.Get("/me/absences/range", api.ListMyAbsencesInRange)
		r.Get("/me/schedule", api.MeSchedule)
		r.Get("/me/vacation-balance", api.MeVacationBalance)

		r.Group(func(r chi.Router) {
			r.Use(middleware.RequireRole("owner", "admin"))
			r.Get("/admin/employees", api.ListEmployees)
			r.Post("/admin/employees", api.CreateEmployee)
			r.Patch("/admin/employees/{id}/schedule", api.AssignEmployeeSchedule)
			r.Get("/admin/employees/{id}/schedule", api.GetEmployeeSchedule)
			r.Get("/admin/schedule-templates", api.ListScheduleTemplates)
			r.Post("/admin/schedule-templates", api.CreateScheduleTemplate)
			r.Patch("/admin/schedule-templates/{id}", api.UpdateScheduleTemplate)
			r.Delete("/admin/schedule-templates/{id}", api.DeleteScheduleTemplate)
			r.Get("/admin/work-centers", api.ListWorkCenters)
			r.Get("/admin/reports/daily", api.DailyReport)
			r.Get("/admin/exports", api.Export)
			r.Get("/admin/corrections", api.ListCorrections)
			r.Patch("/admin/corrections/{id}", api.ReviewCorrection)
			r.Get("/admin/absences", api.ListAbsences)
			r.Patch("/admin/absences/{id}", api.ReviewAbsence)
			r.Post("/admin/billing/checkout", api.CreateCheckout)
		})
	})

	r.Post("/webhooks/stripe", api.StripeWebhook)

	dashStore := dashboard.NewStore(pool)
	dashAuth := dashboard.NewAuthenticator(cfg.AdminDashboardPassword, cfg.JWTSecret)
	dashboard.NewHandler(dashStore, dashAuth).Mount(r)

	go runRetentionJob(compliance.NewRetentionService(pool))

	srv := &http.Server{Addr: cfg.APIAddr, Handler: r}
	go func() {
		log.Printf("API listening on %s", cfg.APIAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}

func runRetentionJob(retention *compliance.RetentionService) {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()
	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		if _, err := retention.EnforceRetention(ctx); err != nil {
			log.Printf("retention job: %v", err)
		}
		cancel()
	}
}
