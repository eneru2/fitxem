package dashboard

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const (
	sessionCookie = "dashboard_session"
	sessionTTL    = 12 * time.Hour
)

type Authenticator struct {
	password string
	secret   []byte
}

func NewAuthenticator(password, secret string) *Authenticator {
	if secret == "" {
		secret = "dashboard-dev-secret"
	}
	return &Authenticator{password: password, secret: []byte(secret)}
}

func (a *Authenticator) Enabled() bool {
	return a.password != ""
}

func (a *Authenticator) CheckPassword(pw string) bool {
	return a.password != "" && pw == a.password
}

func (a *Authenticator) SetSession(w http.ResponseWriter) {
	exp := time.Now().Add(sessionTTL).Unix()
	sig := a.sign(exp)
	val := fmt.Sprintf("%d.%s", exp, sig)
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    val,
		Path:     "/dashboard",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   int(sessionTTL.Seconds()),
	})
}

func (a *Authenticator) ClearSession(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    "",
		Path:     "/dashboard",
		HttpOnly: true,
		MaxAge:   -1,
	})
}

func (a *Authenticator) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !a.validSession(r) {
			if isHTMX(r) {
				w.Header().Set("HX-Redirect", "/dashboard/login")
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			http.Redirect(w, r, "/dashboard/login", http.StatusSeeOther)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (a *Authenticator) validSession(r *http.Request) bool {
	c, err := r.Cookie(sessionCookie)
	if err != nil || c.Value == "" {
		return false
	}
	parts := strings.SplitN(c.Value, ".", 2)
	if len(parts) != 2 {
		return false
	}
	exp, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || time.Now().Unix() > exp {
		return false
	}
	return hmac.Equal([]byte(parts[1]), []byte(a.sign(exp)))
}

func (a *Authenticator) sign(exp int64) string {
	mac := hmac.New(sha256.New, a.secret)
	mac.Write([]byte(strconv.FormatInt(exp, 10)))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func isHTMX(r *http.Request) bool {
	return r.Header.Get("HX-Request") == "true"
}
