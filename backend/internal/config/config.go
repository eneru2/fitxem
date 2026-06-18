package config

import (
	"os"
	"strings"
	"time"
)

type Config struct {
	DatabaseURL    string
	APIAddr        string
	JWTSecret      string
	JWTAccessTTL   time.Duration
	JWTRefreshTTL  time.Duration
	TSAURL         string
	StripeSecret   string
	StripeWebhook  string
	CORSOrigins    []string
	ITSSAPIKey     string
}

func Load() Config {
	_ = loadDotEnv()

	return Config{
		DatabaseURL:   getenv("DATABASE_URL", "postgres://justclock:justclock@localhost:5432/justclock?sslmode=disable"),
		APIAddr:       getenv("API_ADDR", ":8080"),
		JWTSecret:     getenv("JWT_SECRET", "dev-secret-change-in-production"),
		JWTAccessTTL:  parseDuration("JWT_ACCESS_TTL", 15*time.Minute),
		JWTRefreshTTL: parseDuration("JWT_REFRESH_TTL", 168*time.Hour),
		TSAURL:        getenv("TSA_URL", "mock"),
		StripeSecret:  os.Getenv("STRIPE_SECRET_KEY"),
		StripeWebhook: os.Getenv("STRIPE_WEBHOOK_SECRET"),
		CORSOrigins:   splitCSV(getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8081")),
		ITSSAPIKey:    getenv("ITSS_API_KEY", "dev-itss-key"),
	}
}

func loadDotEnv() error {
	for _, path := range []string{".env", "../.env"} {
		if _, err := os.Stat(path); err == nil {
			return tryLoadEnv(path)
		}
	}
	return nil
}

func tryLoadEnv(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		if os.Getenv(key) == "" {
			_ = os.Setenv(key, val)
		}
	}
	return nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseDuration(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return fallback
}

func splitCSV(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
