package dashdata

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

func FormatTime(t time.Time) string {
	return t.In(time.Local).Format("2006-01-02 15:04:05")
}

func FormatDate(t time.Time) string {
	return t.Format("2006-01-02")
}

func ShortID(id uuid.UUID) string {
	s := id.String()
	if len(s) >= 8 {
		return s[:8]
	}
	return s
}

func DerefStr(s *string) string {
	if s == nil {
		return "—"
	}
	return *s
}

func BadgeClass(status string) string {
	switch status {
	case "pending":
		return "badge badge-warn"
	case "approved":
		return "badge badge-ok"
	case "rejected":
		return "badge badge-err"
	case "active", "true":
		return "badge badge-ok"
	case "inactive", "false":
		return "badge badge-muted"
	default:
		return "badge"
	}
}

func EventTypeLabel(t string) string {
	switch t {
	case "in":
		return "Entrada"
	case "out":
		return "Salida"
	case "break_start":
		return "Pausa inicio"
	case "break_end":
		return "Pausa fin"
	default:
		return t
	}
}

func AbsenceTypeLabel(t string) string {
	switch t {
	case "vacation":
		return "Vacaciones"
	case "sick":
		return "Baja"
	case "personal":
		return "Personal"
	case "unpaid":
		return "Sin sueldo"
	default:
		return t
	}
}

func RoleLabel(r string) string {
	switch r {
	case "owner":
		return "Propietario"
	case "admin":
		return "Admin"
	case "employee":
		return "Empleado"
	default:
		return r
	}
}

func FmtInt(n int) string {
	return fmt.Sprintf("%d", n)
}
