package dashboard

import (
	"io/fs"
	"log"
	"net/http"

	"github.com/eneru2/just-clock/dashboard/.klein/views"
	"github.com/eneru2/just-clock/dashboard/public"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type Handler struct {
	store *Store
	auth  *Authenticator
}

func NewHandler(store *Store, auth *Authenticator) *Handler {
	return &Handler{store: store, auth: auth}
}

func (h *Handler) Mount(r chi.Router) {
	if !h.auth.Enabled() {
		log.Println("dashboard: disabled (set ADMIN_DASHBOARD_PASSWORD to enable)")
		return
	}

	static, err := fs.Sub(public.FS, ".")
	if err != nil {
		log.Printf("dashboard: static fs: %v", err)
		return
	}

	r.Route("/dashboard", func(r chi.Router) {
		r.Get("/login", h.Login)
		r.Post("/login", h.LoginPost)
		r.Handle("/static/*", http.StripPrefix("/dashboard/static/", http.FileServer(http.FS(static))))

		r.Group(func(r chi.Router) {
			r.Use(h.auth.Middleware)
			r.Get("/", h.Home)
			r.Post("/logout", h.Logout)

			r.Get("/orgs", h.Orgs)
			r.Get("/orgs/{id}", h.OrgDetail)
			r.Post("/orgs/{id}/tier", h.SetOrgTier)

			r.Get("/employees", h.Employees)
			r.Post("/employees/{id}/toggle-active", h.ToggleEmployee)

			r.Get("/users", h.Users)
			r.Get("/clock-events", h.ClockEvents)
			r.Get("/corrections", h.Corrections)
			r.Get("/absences", h.Absences)
		})
	})

	log.Println("dashboard: enabled at /dashboard")
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	if h.auth.validSession(r) {
		http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
		return
	}
	views.LoginPage("").Render(r.Context(), w)
}

func (h *Handler) LoginPost(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		views.LoginPage("Error en el formulario").Render(r.Context(), w)
		return
	}
	if !h.auth.CheckPassword(r.FormValue("password")) {
		views.LoginPage("Contraseña incorrecta").Render(r.Context(), w)
		return
	}
	h.auth.SetSession(w)
	http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}

func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	h.auth.ClearSession(w)
	http.Redirect(w, r, "/dashboard/login", http.StatusSeeOther)
}

func (h *Handler) Home(w http.ResponseWriter, r *http.Request) {
	stats, err := h.store.GetStats(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	views.HomePage(*stats).Render(r.Context(), w)
}

func (h *Handler) Orgs(w http.ResponseWriter, r *http.Request) {
	search := r.URL.Query().Get("q")
	orgs, err := h.store.ListOrganizations(r.Context(), search, 200)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if isHTMX(r) {
		views.OrgTableBody(orgs).Render(r.Context(), w)
		return
	}
	views.OrgsPage(orgs, search).Render(r.Context(), w)
}

func (h *Handler) OrgDetail(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	org, err := h.store.GetOrganization(r.Context(), id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	orgID := &id
	employees, _ := h.store.ListEmployees(r.Context(), orgID, "", 200)
	users, _ := h.store.ListUsers(r.Context(), orgID, "", 200)
	events, _ := h.store.ListClockEvents(r.Context(), orgID, 100)
	corrections, _ := h.store.ListCorrections(r.Context(), orgID, "", 50)
	absences, _ := h.store.ListAbsences(r.Context(), orgID, "", 50)
	audit, _ := h.store.ListAuditLog(r.Context(), orgID, 50)
	views.OrgDetailPage(*org, employees, users, events, corrections, absences, audit).Render(r.Context(), w)
}

func (h *Handler) SetOrgTier(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	tier := r.FormValue("tier")
	if tier == "" {
		http.Error(w, "tier required", http.StatusBadRequest)
		return
	}
	if err := h.store.SetOrgTier(r.Context(), id, tier); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("HX-Trigger", `{"showToast":"Plan actualizado"}`)
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) Employees(w http.ResponseWriter, r *http.Request) {
	search := r.URL.Query().Get("q")
	employees, err := h.store.ListEmployees(r.Context(), nil, search, 300)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if isHTMX(r) {
		views.EmployeeTableBody(employees, true).Render(r.Context(), w)
		return
	}
	views.EmployeesPage(employees, search).Render(r.Context(), w)
}

func (h *Handler) ToggleEmployee(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	emp, err := h.store.GetEmployee(r.Context(), id)
	if err != nil {
		http.Error(w, "employee not found", http.StatusNotFound)
		return
	}
	if err := h.store.SetEmployeeActive(r.Context(), id, !emp.Active); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	emp.Active = !emp.Active
	views.EmployeeRow(*emp, true).Render(r.Context(), w)
}

func (h *Handler) Users(w http.ResponseWriter, r *http.Request) {
	search := r.URL.Query().Get("q")
	users, err := h.store.ListUsers(r.Context(), nil, search, 300)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if isHTMX(r) {
		views.UserTableBody(users).Render(r.Context(), w)
		return
	}
	views.UsersPage(users, search).Render(r.Context(), w)
}

func (h *Handler) ClockEvents(w http.ResponseWriter, r *http.Request) {
	events, err := h.store.ListClockEvents(r.Context(), nil, 200)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	views.ClockEventsPage(events).Render(r.Context(), w)
}

func (h *Handler) Corrections(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	corrections, err := h.store.ListCorrections(r.Context(), nil, status, 200)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if isHTMX(r) {
		views.CorrectionTable(corrections).Render(r.Context(), w)
		return
	}
	views.CorrectionsPage(corrections, status).Render(r.Context(), w)
}

func (h *Handler) Absences(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	absences, err := h.store.ListAbsences(r.Context(), nil, status, 200)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if isHTMX(r) {
		views.AbsenceTable(absences).Render(r.Context(), w)
		return
	}
	views.AbsencesPage(absences, status).Render(r.Context(), w)
}
