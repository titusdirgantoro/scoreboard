// Command worker runs background jobs (River queue on PostgreSQL): WhatsApp,
// email, PDF certificates, background removal, reminders, payouts.
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"tiusapp.com/scoreboard/internal/infra/config"
	"tiusapp.com/scoreboard/internal/infra/logx"
)

func main() {
	cfg, err := config.FromEnv()
	if err != nil {
		fmt.Fprintln(os.Stderr, "worker:", err)
		os.Exit(1)
	}
	log := logx.New(os.Stdout, cfg.Env, cfg.LogLevel)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// TODO(T-070): buat river.Client dengan pool pgx, daftarkan worker per modul, lalu Start/Stop.
	log.Info("worker mulai (belum ada antrean — dipasang di T-070)", "env", cfg.Env)
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Info("worker berhenti")
			return
		case <-ticker.C:
			log.Debug("worker idle")
		}
	}
}
