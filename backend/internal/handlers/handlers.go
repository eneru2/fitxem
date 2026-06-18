package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/eneru2/just-clock/internal/absence"
	"github.com/eneru2/just-clock/internal/auth"
	"github.com/eneru2/just-clock/internal/billing"
	"github.com/eneru2/just-clock/internal/clock"
	"github.com/eneru2/just-clock/internal/compliance"
	"github.com/eneru2/just-clock/internal/correction"
	"github.com/eneru2/just-clock/internal/itss"
	"github.com/eneru2/just-clock/internal/middleware"
	"github.com/eneru2/just-clock/internal/org"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type API struct {
	Auth       *auth.Service
	Clock      *clock.Service
	Org        *org.Service
	ExportSvc  *compliance.ExportService
	Correction *correction.Service
	Absence    *absence.Service
	Audit      *compliance.AuditService
	ITSS       *itss.Service
	Billing    *billing.Service
}

func (a *API) Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *API) RegisterOrg(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CIF           string `json:"cif"`
		LegalName     string `json:"legal_name"`
		OwnerEmail    string `json:"owner_email"`
		OwnerPassword string `json:"owner_password"`
		OwnerName     string `json:"owner_name"`
		OwnerNIF      string `json:"owner_nif"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	res, err := a.Auth.RegisterOrg(r.Context(), auth.RegisterOrgInput{
		CIF: req.CIF, LegalName: req.LegalName, OwnerEmail: req.OwnerEmail,
		OwnerPassword: req.OwnerPassword, OwnerName: req.OwnerName, OwnerNIF: req.OwnerNIF,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	_ = a.Audit.Log(r.Context(), res.OrgID, &res.UserID, "register_org", "organization", &res.OrgID, middleware.ClientIP(r), nil)
	writeJSON(w, http.StatusCreated, res)
}

func (a *API) Login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	tokens, user, err := a.Auth.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	_ = a.Audit.Log(r.Context(), user.OrgID, &user.ID, "login", "user", &user.ID, middleware.ClientIP(r), nil)
	writeJSON(w, http.StatusOK, map[string]any{
		"access_token":  tokens.AccessToken,
		"refresh_token": tokens.RefreshToken,
		"expires_in":    tokens.ExpiresIn,
		"role":          user.Role,
		"email":         user.Email,
	})
}

func (a *API) Refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	tokens, err := a.Auth.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	writeJSON(w, http.StatusOK, tokens)
}

func (a *API) ClockIn(w http.ResponseWriter, r *http.Request)  { a.recordClock(w, r, clock.EventIn) }
func (a *API) ClockOut(w http.ResponseWriter, r *http.Request) { a.recordClock(w, r, clock.EventOut) }
func (a *API) BreakStart(w http.ResponseWriter, r *http.Request) { a.recordClock(w, r, clock.EventBreakStart) }
func (a *API) BreakEnd(w http.ResponseWriter, r *http.Request) { a.recordClock(w, r, clock.EventBreakEnd) }

func (a *API) recordClock(w http.ResponseWriter, r *http.Request, eventType clock.EventType) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	userID := parseUUID(claims.UserID)
	employeeID, err := a.Clock.EmployeeIDForUser(r.Context(), orgID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "employee not linked to user")
		return
	}
	var body struct {
		ClientAt  *time.Time `json:"client_at"`
		HourType  string     `json:"hour_type"`
		Latitude  *float64   `json:"latitude"`
		Longitude *float64   `json:"longitude"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	if err := clock.ValidateCoordinates(body.Latitude, body.Longitude); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	ev, err := a.Clock.Record(r.Context(), clock.RecordInput{
		OrgID: orgID, EmployeeID: employeeID, EventType: eventType,
		ClientAt: body.ClientAt, HourType: body.HourType,
		Latitude: body.Latitude, Longitude: body.Longitude,
	})
	if err != nil {
		if errors.Is(err, clock.ErrInvalidTransition) {
			writeError(w, http.StatusConflict, "invalid clock transition")
			return
		}
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	_ = a.Audit.Log(r.Context(), orgID, &userID, "clock_"+string(eventType), "clock_event", &ev.ID, middleware.ClientIP(r), ev)
	writeJSON(w, http.StatusCreated, ev)
}

func (a *API) MeToday(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	userID := parseUUID(claims.UserID)
	employeeID, err := a.Clock.EmployeeIDForUser(r.Context(), orgID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "employee not found")
		return
	}
	summary, err := a.Clock.TodaySummary(r.Context(), orgID, employeeID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, summary)
}

func (a *API) MeRecords(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	userID := parseUUID(claims.UserID)
	employeeID, err := a.Clock.EmployeeIDForUser(r.Context(), orgID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "employee not found")
		return
	}
	from, to := parseDateRange(r)
	events, err := a.Clock.ListRecords(r.Context(), orgID, employeeID, from, to)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": events})
}

func (a *API) ListEmployees(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	employees, err := a.Org.ListEmployees(r.Context(), parseUUID(claims.OrgID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"employees": employees})
}

func (a *API) CreateEmployee(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	var req struct {
		NIF      string `json:"nif"`
		FullName string `json:"full_name"`
		Email    string `json:"email"`
		Password string `json:"password"`
		Role     string `json:"role"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	e, err := a.Org.CreateEmployee(r.Context(), org.CreateEmployeeInput{
		OrgID: parseUUID(claims.OrgID), NIF: req.NIF, FullName: req.FullName,
		Email: req.Email, Password: req.Password, Role: req.Role,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	uid := parseUUID(claims.UserID)
	_ = a.Audit.Log(r.Context(), parseUUID(claims.OrgID), &uid, "create_employee", "employee", &e.ID, middleware.ClientIP(r), e)
	writeJSON(w, http.StatusCreated, e)
}

func (a *API) DailyReport(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	from, to := parseDateRange(r)
	records, err := a.Clock.ListOrgRecords(r.Context(), parseUUID(claims.OrgID), from, to)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"records": records})
}

func (a *API) Export(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	o, err := a.Org.GetOrg(r.Context(), orgID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	from, to := parseDateRange(r)
	format := r.URL.Query().Get("format")
	if format == "" {
		format = "json"
	}
	req := compliance.ExportRequest{OrgID: orgID, From: from, To: to, CIF: o.CIF}

	var data []byte
	var contentType string
	switch format {
	case "xml":
		data, err = a.ExportSvc.ExportXML(r.Context(), req)
		contentType = "application/xml"
	case "pdf":
		data, err = a.ExportSvc.ExportPDF(r.Context(), req)
		contentType = "application/pdf"
	default:
		data, err = a.ExportSvc.ExportJSON(r.Context(), req)
		contentType = "application/json"
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	uid := parseUUID(claims.UserID)
	_ = a.Audit.Log(r.Context(), orgID, &uid, "export_"+format, "export", nil, middleware.ClientIP(r), map[string]string{"format": format})
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", "attachment; filename=just-clock-export."+format)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func (a *API) CreateCorrection(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	var req struct {
		EmployeeID     uuid.UUID  `json:"employee_id"`
		EventType      string     `json:"event_type"`
		ProposedAt     time.Time  `json:"proposed_at"`
		Reason         string     `json:"reason"`
		IncidentType   string     `json:"incident_type"`
		RelatedEventID *uuid.UUID `json:"related_event_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Reason == "" {
		writeError(w, http.StatusBadRequest, "reason is required")
		return
	}
	uid := parseUUID(claims.UserID)
	cr, err := a.Correction.Create(r.Context(), correction.CreateInput{
		OrgID: parseUUID(claims.OrgID), EmployeeID: req.EmployeeID,
		RequestedBy: uid, EventType: clock.EventType(req.EventType),
		ProposedAt: req.ProposedAt, Reason: req.Reason,
		IncidentType: correction.IncidentType(req.IncidentType),
		RelatedEventID: req.RelatedEventID,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, cr)
}

func (a *API) ListMyCorrections(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	userID := parseUUID(claims.UserID)
	employeeID, err := a.Clock.EmployeeIDForUser(r.Context(), orgID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "employee not found")
		return
	}
	list, err := a.Correction.ListMine(r.Context(), orgID, employeeID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"corrections": list})
}

func (a *API) ReviewCorrection(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req struct {
		Approve bool `json:"approve"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	cr, err := a.Correction.Review(r.Context(), parseUUID(claims.OrgID), id, parseUUID(claims.UserID), req.Approve)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, cr)
}

func (a *API) ListCorrections(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	list, err := a.Correction.ListPending(r.Context(), parseUUID(claims.OrgID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"corrections": list})
}

func (a *API) CreateAbsence(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	var req struct {
		EmployeeID  uuid.UUID `json:"employee_id"`
		AbsenceType string    `json:"absence_type"`
		StartDate   string    `json:"start_date"`
		EndDate     string    `json:"end_date"`
		Reason      string    `json:"reason"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.Reason == "" {
		writeError(w, http.StatusBadRequest, "reason is required")
		return
	}
	start, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid start_date")
		return
	}
	end, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid end_date")
		return
	}
	uid := parseUUID(claims.UserID)
	ar, err := a.Absence.Create(r.Context(), absence.CreateInput{
		OrgID: parseUUID(claims.OrgID), EmployeeID: req.EmployeeID,
		RequestedBy: uid, AbsenceType: absence.AbsenceType(req.AbsenceType),
		StartDate: start, EndDate: end, Reason: req.Reason,
	})
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, ar)
}

func (a *API) ListMyAbsences(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	userID := parseUUID(claims.UserID)
	employeeID, err := a.Clock.EmployeeIDForUser(r.Context(), orgID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "employee not found")
		return
	}
	list, err := a.Absence.ListMine(r.Context(), orgID, employeeID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"absences": list})
}

func (a *API) ListMyAbsencesInRange(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	orgID := parseUUID(claims.OrgID)
	userID := parseUUID(claims.UserID)
	employeeID, err := a.Clock.EmployeeIDForUser(r.Context(), orgID, userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "employee not found")
		return
	}
	from, to := parseDateRange(r)
	list, err := a.Absence.ListApprovedInRange(r.Context(), orgID, employeeID, from, to)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"absences": list})
}

func (a *API) ListAbsences(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	list, err := a.Absence.ListPending(r.Context(), parseUUID(claims.OrgID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"absences": list})
}

func (a *API) ReviewAbsence(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req struct {
		Approve bool `json:"approve"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	ar, err := a.Absence.Review(r.Context(), parseUUID(claims.OrgID), id, parseUUID(claims.UserID), req.Approve)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, ar)
}

func (a *API) GetOrg(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	o, err := a.Org.GetOrg(r.Context(), parseUUID(claims.OrgID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, o)
}

func (a *API) ListWorkCenters(w http.ResponseWriter, r *http.Request) {
	claims := middleware.ClaimsFromContext(r.Context())
	list, err := a.Org.ListWorkCenters(r.Context(), parseUUID(claims.OrgID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"work_centers": list})
}

func (a *API) ITSSRecords(w http.ResponseWriter, r *http.Request) {
	cif := chi.URLParam(r, "cif")
	from, to := parseDateRange(r)
	res, err := a.ITSS.GetCompanyRecords(r.Context(), cif, from, to, middleware.ClientIP(r))
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (a *API) ITSSEmployeeRecords(w http.ResponseWriter, r *http.Request) {
	cif := chi.URLParam(r, "cif")
	nif := chi.URLParam(r, "nif")
	from, to := parseDateRange(r)
	res, err := a.ITSS.GetEmployeeRecords(r.Context(), cif, nif, from, to, middleware.ClientIP(r))
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (a *API) ITSSAuditLog(w http.ResponseWriter, r *http.Request) {
	cif := chi.URLParam(r, "cif")
	from, to := parseDateRange(r)
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	logs, err := a.ITSS.GetAuditLog(r.Context(), cif, from, to, limit, middleware.ClientIP(r))
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"audit_log": logs})
}

func (a *API) StripeWebhook(w http.ResponseWriter, r *http.Request) {
	a.Billing.HandleWebhook(w, r)
}

func (a *API) CreateCheckout(w http.ResponseWriter, r *http.Request) {
	a.Billing.CreateCheckoutSession(w, r)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func parseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}

func parseDateRange(r *http.Request) (time.Time, time.Time) {
	fromStr := r.URL.Query().Get("from")
	toStr := r.URL.Query().Get("to")
	now := time.Now().UTC()
	from := now.AddDate(0, 0, -30)
	to := now
	if fromStr != "" {
		if t, err := time.Parse(time.RFC3339, fromStr); err == nil {
			from = t
		}
	}
	if toStr != "" {
		if t, err := time.Parse(time.RFC3339, toStr); err == nil {
			to = t
		}
	}
	return from, to
}
