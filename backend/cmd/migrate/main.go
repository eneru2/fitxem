package main

import (
	"log"

	"github.com/eneru2/just-clock/internal/config"
	"github.com/eneru2/just-clock/internal/db"
)

func main() {
	cfg := config.Load()
	if err := db.Migrate(cfg.DatabaseURL, "migrations"); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	log.Println("migrations applied")
}
